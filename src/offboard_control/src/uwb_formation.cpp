#include <iostream>

#include <rclcpp/rclcpp.hpp>
#include <rclcpp/clock.hpp>

#include <boost/filesystem.hpp>

#include <px4_msgs/msg/offboard_control_mode.hpp>
#include <px4_msgs/msg/trajectory_setpoint.hpp>
#include <px4_msgs/msg/vehicle_status.hpp>
#include <px4_msgs/msg/vehicle_command.hpp>
#include <px4_msgs/msg/vehicle_control_mode.hpp>
#include <px4_msgs/msg/vehicle_local_position.hpp>
#include <px4_msgs/msg/vehicle_attitude.hpp>

#include <uwb_ros_msgs/msg/uwb.hpp>

#include <Eigen/Dense>

#define MAC_ADDR_LEADER 10585080495009735346

using std::placeholders::_1;
using namespace std::chrono_literals;

Eigen::Vector3d transform_vector_quat(Eigen::Vector3d v, Eigen::Quaterniond q){
    Eigen::Vector3d v_rot = q * v;
    return v_rot;
}

class UwbFormation : public rclcpp::Node
{
    public:
        UwbFormation() : rclcpp::Node("UwbFormation"){
            // Declare the robot_id ROS2 parameter
            auto param_desc = rcl_interfaces::msg::ParameterDescriptor();
            param_desc.description = "ID of the robot. This is the system id of each PX4 instance.";
            this->declare_parameter("robot_id", 1, param_desc);
            param_desc.description = "Altitude at which the flock operates (from the ground) (m).";
            this->declare_parameter("altitude", 0.5, param_desc);
            param_desc.description = "Frequency of the timer of the command loop (Hz)";
            this->declare_parameter("freq_cmd_loop", 10, param_desc);
            param_desc.description = "Max velocity (m/s)";
            this->declare_parameter("max_vel", 0.3, param_desc);
            param_desc.description = "Controller proportional gain";
            this->declare_parameter("kp", 0.5, param_desc);
            param_desc.description = "Inter-robot distance";
            this->declare_parameter("inter_robot_dist", 1.5, param_desc);
            param_desc.description = "True if this is the drone on the right";
            this->declare_parameter("right", true, param_desc);
            param_desc.description = "Path to the log file";
            this->declare_parameter("log_path", "", param_desc);

            this->robot_id = this->get_parameter("robot_id").get_parameter_value().get<uint8_t>();
            this->altitude = this->get_parameter("altitude").get_parameter_value().get<double>();
            this->timer_period = std::chrono::microseconds(1000000/this->get_parameter("freq_cmd_loop").get_parameter_value().get<uint32_t>());
            const std::string log_path = this->get_parameter("log_path").as_string();
            this->max_vel = this->get_parameter("max_vel").get_parameter_value().get<double>();
            this->kp = this->get_parameter("kp").get_parameter_value().get<double>();
            this->inter_robot_distance = this->get_parameter("inter_robot_dist").get_parameter_value().get<double>();
            this->right = this->get_parameter("right").get_parameter_value().get<bool>();

            if(robot_id <= 0){
                RCLCPP_FATAL(this->get_logger(), "Wrong robot ID ! Robot IDs must start at 1. Received: %i", robot_id);
                exit(EXIT_FAILURE);
            }

            // -- Logging
            if(log_path != "")
            {
                if(boost::filesystem::create_directory(log_path)){
                    RCLCPP_DEBUG(this->get_logger(), "Created a new directory to hold the log file.");
                } else if(!boost::filesystem::is_directory(log_path)){
                    RCLCPP_FATAL(this->get_logger(), "Failed to create logging directory (%s). Is it a correct path ?", log_path.c_str());
                    exit(EXIT_FAILURE);
                }
                // Define the output file name, based on the existing files in the experience folder (incremental)
                std::string temp_path;
                int i = 1;
                while(m_output_file.empty()){
                    temp_path = log_path+"position_control_log_"+std::to_string(i)+".csv";
                    if(boost::filesystem::exists(temp_path)){
                        i++;
                    } else {
                        m_output_file = temp_path;
                    }
                }

                // initialize the output file with headers
                this->f.open(m_output_file.c_str(), std::ios::out);
                this->f << "Time[us],x[m],y[m],z[m],yaw[rad]"
                << std::endl;
                this->f.close();
            }
            // -- End logging

            // Prepare the QoS that we will assign to the publishers / subscribers  
            auto qos_sub = rclcpp::QoS(rclcpp::KeepLast(10)).best_effort().durability_volatile();
	        auto qos_pub = rclcpp::QoS(rclcpp::KeepLast(10)).best_effort().transient_local();
            
            // ---------- SUBSCRIBERS ----------

            // Create a subscriber to the vehicle's status topic. Used to get arming state and vehicle's mode
            this->vehicle_status_sub_ = this->create_subscription<px4_msgs::msg::VehicleStatus>(
                            "px4_"+std::to_string(this->robot_id)+
                            "/fmu/out/vehicle_status",
                            qos_sub, 
                            std::bind(&UwbFormation::vehicle_status_clbk, this, _1)
            );

            this->uwb_sub_ = this->create_subscription<uwb_ros_msgs::msg::Uwb>(
                            "px4_"+std::to_string(this->robot_id)+
                            "/uwb",
                            qos_sub,
                            std::bind(&UwbFormation::uwb_clbk, this, _1)
            );

            this->vehicle_attitude_sub_ = this->create_subscription<px4_msgs::msg::VehicleAttitude>(
                            "/px4_"+std::to_string(robot_id)+
                            "/fmu/out/vehicle_attitude",
                            qos_sub,
                            std::bind(&UwbFormation::vehicle_attitude_clbk, this, _1)
            );


            // ---------- PUBLISHERS ----------
            this->offboard_control_mode_publisher_ =
                    this->create_publisher<px4_msgs::msg::OffboardControlMode>(
                        "px4_"+std::to_string(this->robot_id)+
                        "/fmu/in/offboard_control_mode", qos_pub);
            this->trajectory_setpoint_publisher_ =
                    this->create_publisher<px4_msgs::msg::TrajectorySetpoint>(
                        "px4_"+std::to_string(this->robot_id)+
                        "/fmu/in/trajectory_setpoint", qos_pub);
            this->vehicle_command_publisher_ = 
                    this->create_publisher<px4_msgs::msg::VehicleCommand>(
                        "px4_"+std::to_string(this->robot_id)+
                        "/fmu/in/vehicle_command", qos_pub);
            
            // start publisher timer
            timer_ = rclcpp::create_timer(this, this->get_clock(), this->timer_period, std::bind(&UwbFormation::timer_clbk, this));
        }

        void arm() ;
	    void disarm() ;
        void engage_offboard_mode();

    private:
        rclcpp::TimerBase::SharedPtr timer_;
        std::chrono::microseconds timer_period;
        uint64_t offboard_setpoint_counter_;   //!< counter for the number of setpoints sent
        uint8_t nav_state;
	    uint8_t arming_state;
        Eigen::Vector3d cmd;
        uint8_t robot_id;
        double altitude;
        std::map<uint64_t, uwb_ros_msgs::msg::Uwb> uwb_distances;
        double inter_robot_distance;
        double max_vel;
        double kp;
        bool right;
        Eigen::Quaterniond q;


        // logging
        std::string m_output_file;
        std::ofstream f;

        // Subscribers
        rclcpp::Subscription<px4_msgs::msg::VehicleStatus>::SharedPtr vehicle_status_sub_;
        rclcpp::Subscription<uwb_ros_msgs::msg::Uwb>::SharedPtr uwb_sub_;
        rclcpp::Subscription<px4_msgs::msg::VehicleAttitude>::SharedPtr vehicle_attitude_sub_;


        // publishers
        rclcpp::Publisher<px4_msgs::msg::OffboardControlMode>::SharedPtr offboard_control_mode_publisher_;
        rclcpp::Publisher<px4_msgs::msg::TrajectorySetpoint>::SharedPtr trajectory_setpoint_publisher_;
        rclcpp::Publisher<px4_msgs::msg::VehicleCommand>::SharedPtr vehicle_command_publisher_;

        // Callbacks
        void timer_clbk();
        void vehicle_status_clbk(const px4_msgs::msg::VehicleStatus & msg);
        void uwb_clbk(const uwb_ros_msgs::msg::Uwb & msg);
        void vehicle_attitude_clbk(const px4_msgs::msg::VehicleAttitude & msg);


        // commands
        void publish_offboard_control_mode(int mode);
        void publish_setpoint_position(Eigen::Vector3d target, float yaw_speed);
        void publish_setpoint_velocity(Eigen::Vector3d target, float yaw_speed);
        void publish_vehicle_command(uint16_t command, float param1 = 0.0, float param2 = 0.0, uint8_t system_id = 0);

};

void UwbFormation::timer_clbk()
{
    Eigen::Vector3d cmd = {0.0, 0.0, 0.0};

    for(auto uwb_msg : this->uwb_distances){
        if(uwb_msg.first == MAC_ADDR_LEADER){
            cmd[0] = this->kp * (uwb_msg.second.distance - this->inter_robot_distance);
        } 
        // else {
        //     cmd[1] = this->kp * (uwb_msg.second.distance - this->inter_robot_distance);
        // }
    }
    // if(this->right){
    //     cmd[1] = -cmd[1];
    // }

    if(cmd.norm() > this->max_vel){
        cmd = cmd.normalized() * this->max_vel;
    }

    if(this->nav_state != px4_msgs::msg::VehicleStatus::NAVIGATION_STATE_OFFBOARD){
        this->publish_offboard_control_mode(0);
        this->engage_offboard_mode();

        // Arm the vehicle
        this->arm();
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    } else {
        this->offboard_setpoint_counter_++;
    }

    if(this->offboard_setpoint_counter_ < 100 && this->offboard_setpoint_counter_ != 0){
        cmd = {0.0, 0.0, -2.0};

        RCLCPP_INFO(this->get_logger(), "Sending setpoint position : %f %f %f", cmd[0], cmd[1], cmd[2]);;

        this->publish_offboard_control_mode(0);
        this->publish_setpoint_position(transform_vector_quat(cmd, this->q), NAN);
    }

    if(this->offboard_setpoint_counter_ > 100){
        RCLCPP_INFO(this->get_logger(), "Sending setpoint velocity: %f %f %f", cmd[0], cmd[1], cmd[2]);;

        this->publish_offboard_control_mode(1);
        this->publish_setpoint_velocity(transform_vector_quat(cmd, this->q), NAN);
    }

}


/**
 * @brief Save the distance to neighbors in local memory
 */
void UwbFormation::uwb_clbk(const uwb_ros_msgs::msg::Uwb & msg)
{
    this->uwb_distances[msg.id] = msg;
}

/**
 * @brief Save the arming state and navigation state received in the last VehicleStatus update
 */
void UwbFormation::vehicle_status_clbk(const px4_msgs::msg::VehicleStatus & msg)
{
    this->arming_state = msg.arming_state;
    this->nav_state = msg.nav_state;
}

void UwbFormation::vehicle_attitude_clbk(const px4_msgs::msg::VehicleAttitude & msg){
    this->q = Eigen::Quaterniond(msg.q[0], msg.q[1], msg.q[2], msg.q[3]);
}

/**
 * @brief Send a command to Arm the vehicle
 */
void UwbFormation::arm()
{
    // send the arm command in a VehicleCommand message. the third parameter is the default parameter, it has no impact
	publish_vehicle_command(px4_msgs::msg::VehicleCommand::VEHICLE_CMD_COMPONENT_ARM_DISARM, 1.0, 0.0, this->robot_id);

	RCLCPP_INFO(this->get_logger(), "Arm command sent");
}

/**
 * @brief Send a command to Disarm the vehicle
 */
void UwbFormation::disarm()
{
    // send the disarm command in a VehicleCommand message. the third parameter is the default parameter, it has no impact
	publish_vehicle_command(px4_msgs::msg::VehicleCommand::VEHICLE_CMD_COMPONENT_ARM_DISARM, 0.0, 0.0, this->robot_id);

	RCLCPP_INFO(this->get_logger(), "Disarm command sent");
}

/**
 * @brief Send a command to set the vehicle to Offboard mode
 */
void UwbFormation::engage_offboard_mode()
{
    // send the arm command in a VehicleCommand message. 1 is offboard, 6 is ???
    publish_vehicle_command(px4_msgs::msg::VehicleCommand::VEHICLE_CMD_DO_SET_MODE, 1.0, 6.0, this->robot_id);

    RCLCPP_INFO(this->get_logger(), "Set Offboard mode command sent");
}

/**
 * @brief Publish the offboard control mode.
 *        For this example, only position and altitude controls are active.
 */
void UwbFormation::publish_offboard_control_mode(int mode){
	px4_msgs::msg::OffboardControlMode msg{};
	msg.timestamp = int(this->get_clock()->now().nanoseconds() / 1000);
    if(mode == 0){
        msg.position = true;
        msg.velocity = false;
    } else if(mode == 1){
        msg.position = false;
        msg.velocity = true;
    } else {
        exit(EXIT_FAILURE);
    }
	msg.acceleration = false;
	msg.attitude = false;
	msg.body_rate = false;

	offboard_control_mode_publisher_->publish(msg);
}

/**
 * @brief Publish a trajectory setpoint
 *        For this example, it sends a trajectory setpoint to make the
 *        vehicle hover at 5 meters with a yaw angle of 180 degrees.
 */
void UwbFormation::publish_setpoint_velocity(Eigen::Vector3d target, float yaw){
	px4_msgs::msg::TrajectorySetpoint msg{};
	msg.timestamp = int(this->get_clock()->now().nanoseconds() / 1000);

    msg.position[0] = NAN;
    msg.position[1] = NAN;
    msg.position[2] = NAN; // The Z axis is toward the ground

    msg.velocity[0] = target[0];
    msg.velocity[1] = target[1];
    msg.velocity[2] = target[2];

    msg.acceleration[0] = NAN;
    msg.acceleration[1] = NAN;
    msg.acceleration[2] = NAN;

    msg.jerk[0] = NAN;
    msg.jerk[1] = NAN;
    msg.jerk[2] = NAN;

    msg.yaw = yaw;

    // RCLCPP_INFO(this->get_logger(), "My position: %f, %f, %f", this->robots_data[this->robot_id-1].position[0], this->robots_data[this->robot_id-1].position[1], this->robots_data[this->robot_id-1].position[2]);

    // RCLCPP_DEBUG(this->get_logger(), "Sending trajectory setpoint to UAV %i: at position %f, %f, %f", this->robot_id, msg.position[0], msg.position[1], msg.position[2]);
    // RCLCPP_INFO(this->get_logger(), "Sending trajectory setpoint to UAV %i: at velocity %f, %f, %f", this->robot_id, msg.velocity[0], msg.velocity[1], msg.velocity[2]);
    // RCLCPP_INFO(this->get_logger(), "Sending trajectory setpoint to UAV %i: at acceleration %f, %f, %f", this->robot_id, msg.acceleration[0], msg.acceleration[1], msg.acceleration[2]);

    trajectory_setpoint_publisher_->publish(msg);
}

/**
 * @brief Publish a trajectory setpoint
 *        For this example, it sends a trajectory setpoint to make the
 *        vehicle hover at 5 meters with a yaw angle of 180 degrees.
 */
void UwbFormation::publish_setpoint_position(Eigen::Vector3d target, float yaw){
	px4_msgs::msg::TrajectorySetpoint msg{};
	msg.timestamp = int(this->get_clock()->now().nanoseconds() / 1000);

    msg.position[0] = target[0];
    msg.position[1] = target[1];
    msg.position[2] = target[2]; // The Z axis is toward the ground

    msg.velocity[0] = NAN;
    msg.velocity[1] = NAN;
    msg.velocity[2] = NAN;

    msg.acceleration[0] = NAN;
    msg.acceleration[1] = NAN;
    msg.acceleration[2] = NAN;

    msg.jerk[0] = NAN;
    msg.jerk[1] = NAN;
    msg.jerk[2] = NAN;

    msg.yaw = yaw;

    // RCLCPP_INFO(this->get_logger(), "My position: %f, %f, %f", this->robots_data[this->robot_id-1].position[0], this->robots_data[this->robot_id-1].position[1], this->robots_data[this->robot_id-1].position[2]);

    // RCLCPP_DEBUG(this->get_logger(), "Sending trajectory setpoint to UAV %i: at position %f, %f, %f", this->robot_id, msg.position[0], msg.position[1], msg.position[2]);
    // RCLCPP_INFO(this->get_logger(), "Sending trajectory setpoint to UAV %i: at velocity %f, %f, %f", this->robot_id, msg.velocity[0], msg.velocity[1], msg.velocity[2]);
    // RCLCPP_INFO(this->get_logger(), "Sending trajectory setpoint to UAV %i: at acceleration %f, %f, %f", this->robot_id, msg.acceleration[0], msg.acceleration[1], msg.acceleration[2]);

    trajectory_setpoint_publisher_->publish(msg);
}



/**
 * @brief Publish vehicle commands
 * @param command   Command code (matches VehicleCommand and MAVLink MAV_CMD codes)
 * @param param1    Command parameter 1
 * @param param2    Command parameter 2
 */
void UwbFormation::publish_vehicle_command(uint16_t command, float param1, float param2, uint8_t system_id)
{
	px4_msgs::msg::VehicleCommand msg{};
	msg.param1 = param1;
	msg.param2 = param2;
	msg.command = command;
	msg.target_system = system_id;
	msg.target_component = 1;
	msg.source_system = 1;
	msg.source_component = 1;
	msg.from_external = true;
	msg.timestamp = this->get_clock()->now().nanoseconds() / 1000;
	this->vehicle_command_publisher_->publish(msg);
}


int main(int argc, char** argv){
    rclcpp::init(argc, argv);
    rclcpp::spin(std::make_shared<UwbFormation>());
    rclcpp::shutdown();
    return 0;
}