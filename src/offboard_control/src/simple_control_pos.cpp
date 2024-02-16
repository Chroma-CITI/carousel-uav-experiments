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

#include <Eigen/Dense>

using std::placeholders::_1;
using namespace std::chrono_literals;

class SimpleControl : public rclcpp::Node
{
    public:
        SimpleControl() : rclcpp::Node("SimpleControl"){

            // Declare the robot_id ROS2 parameter
            auto param_desc = rcl_interfaces::msg::ParameterDescriptor();
            param_desc.description = "ID of the robot. This is the system id of each PX4 instance.";
            this->declare_parameter("robot_id", 1, param_desc);
            param_desc.description = "Altitude of takeoff (from the ground) (m).";
            this->declare_parameter("takeoff_altitude", 0.5, param_desc);
            param_desc.description = "Frequency of the timer of the command loop (Hz)";
            this->declare_parameter("freq_cmd_loop", 10, param_desc);
            param_desc.description = "Rotation speed (rad/s)";
            this->declare_parameter("omega", 0.3, param_desc);
            param_desc.description = "Path to the log file";
            this->declare_parameter("log_path", "", param_desc);


            this->robot_id = this->get_parameter("robot_id").get_parameter_value().get<uint8_t>();
            this->takeoff_altitude = this->get_parameter("takeoff_altitude").get_parameter_value().get<double>();
            this->timer_period = std::chrono::microseconds(1000000/this->get_parameter("freq_cmd_loop").get_parameter_value().get<uint32_t>());
            this->omega = this->get_parameter("omega").get_parameter_value().get<double>();
            const std::string log_path = this->get_parameter("log_path").as_string();

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
                            std::bind(&SimpleControl::vehicle_status_clbk, this, _1)
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

		    this->offboard_setpoint_counter_ = 0;

            this->takeoff_speed = 4.0;
            this->radius = 10.0; // m
            this->theta = 0.0; // rad
            this->x = 0.0;
            this->y = 0.0;
            this->a = 8;
            this->send_cmd = true;

            auto cmdloop_callback = [this]() -> void {
                if(this->nav_state != px4_msgs::msg::VehicleStatus::NAVIGATION_STATE_OFFBOARD){
                    this->engage_offboard_mode();

                    // Arm the vehicle
                    this->arm();
                    std::this_thread::sleep_for(std::chrono::milliseconds(100));
                }

                this->cmd = {this->x, this->y, -this->takeoff_altitude};

                // Publish the offboard control mode at each loop : Mandatory to keep this topic published > 2 Hz to keep the offboard mode
                // if(send_cmd){
                    this->publish_offboard_control_mode();
                // }

                // if(this->offboard_setpoint_counter_ % 10 == 0){
                //     this->send_cmd = !send_cmd;
                // }

                double t = this->offboard_setpoint_counter_ *0.1* this->timer_period.count()/1000000.0; // period of the control loop, in seconds
                
                // This is a security : make sure the vehicle is in "Offboard mode" before sending the setpoints
                // if(this->nav_state == px4_msgs::msg::VehicleStatus::NAVIGATION_STATE_OFFBOARD){
                    
                    // if(send_cmd){
                        this->publish_trajectory_setpoint(cmd, this->theta);
                    // }

                    // CAROUSSEL
                    // this->x = 0.0;
                    // this->y = 0.0;
                    // this->theta += this->omega*(this->timer_period.count()/1000000.0);
                    this->theta = M_PI/2;

                    // ALLER - RETOUR
                    if((this->offboard_setpoint_counter_ % 1000) > 500){
                        this->x = 1.0;
                    } else {
                        this->x = -1.0;
                    }

                    // INFINITY SYMBOL
                    // this->x = (this->a*std::cos(t))/(1+std::pow(std::sin(t),2));
                    // this->y = (this->a*std::sin(t)*std::cos(t))/(1+std::pow(std::sin(t),2));

                // }

                this->offboard_setpoint_counter_++;

            };

            // start publisher timer
            timer_ = this->create_wall_timer(timer_period, cmdloop_callback);
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
        double takeoff_speed;
        double takeoff_altitude;
        double radius;
        double theta;
        double omega;
        uint8_t robot_id;
        double x;
        double y;
        double a;
        bool send_cmd;

        // logging
        std::string m_output_file;
        std::ofstream f;

        // Subscribers
        rclcpp::Subscription<px4_msgs::msg::VehicleStatus>::SharedPtr vehicle_status_sub_;

        // publishers
        rclcpp::Publisher<px4_msgs::msg::OffboardControlMode>::SharedPtr offboard_control_mode_publisher_;
        rclcpp::Publisher<px4_msgs::msg::TrajectorySetpoint>::SharedPtr trajectory_setpoint_publisher_;
        rclcpp::Publisher<px4_msgs::msg::VehicleCommand>::SharedPtr vehicle_command_publisher_;

        // callbacks
        void vehicle_status_clbk(const px4_msgs::msg::VehicleStatus & msg);

        void save_trajectory_setpoint(const px4_msgs::msg::TrajectorySetpoint & msg);

        // commands
        void publish_offboard_control_mode();
        void publish_trajectory_setpoint(Eigen::Vector3d target, float yaw_speed);
        void publish_vehicle_command(uint16_t command, float param1 = 0.0, float param2 = 0.0, uint8_t system_id = 0);

};

/**
 * @brief Send a command to Arm the vehicle
 */
void SimpleControl::arm()
{
    // send the arm command in a VehicleCommand message. the third parameter is the default parameter, it has no impact
	publish_vehicle_command(px4_msgs::msg::VehicleCommand::VEHICLE_CMD_COMPONENT_ARM_DISARM, 1.0, 0.0, this->robot_id);

	RCLCPP_INFO(this->get_logger(), "Arm command sent");
}

/**
 * @brief Send a command to Disarm the vehicle
 */
void SimpleControl::disarm()
{
    // send the disarm command in a VehicleCommand message. the third parameter is the default parameter, it has no impact
	publish_vehicle_command(px4_msgs::msg::VehicleCommand::VEHICLE_CMD_COMPONENT_ARM_DISARM, 0.0, 0.0, this->robot_id);

	RCLCPP_INFO(this->get_logger(), "Disarm command sent");
}

/**
 * @brief Send a command to set the vehicle to Offboard mode
 */
void SimpleControl::engage_offboard_mode()
{
    // send the arm command in a VehicleCommand message. 1 is offboard, 6 is ???
    publish_vehicle_command(px4_msgs::msg::VehicleCommand::VEHICLE_CMD_DO_SET_MODE, 1.0, 6.0, this->robot_id);

    RCLCPP_INFO(this->get_logger(), "Set Offboard mode command sent");
}

/**
 * @brief Save the arming state and navigation state received in the last VehicleStatus update
 */
void SimpleControl::vehicle_status_clbk(const px4_msgs::msg::VehicleStatus & msg)
{
    this->arming_state = msg.arming_state;
    this->nav_state = msg.nav_state;
}


/**
 * @brief Save the X, Y, Z, Yaw values of a TrajectorySetpoint to a csv-like file.
 */
void SimpleControl::save_trajectory_setpoint(const px4_msgs::msg::TrajectorySetpoint & msg)
{
    this->f.open(this->m_output_file.c_str(), std::fstream::app);
    this->f << msg.timestamp <<","<< msg.position[0] <<","<< msg.position[1] <<","<< msg.position[2] <<","<< msg.yaw << "\n";
    this->f.close();
}

/**
 * @brief Publish the offboard control mode.
 *        For this example, only position and altitude controls are active.
 */
void SimpleControl::publish_offboard_control_mode(){
	px4_msgs::msg::OffboardControlMode msg{};
	msg.timestamp = int(this->get_clock()->now().nanoseconds() / 1000);
	msg.position = true;
	msg.velocity = false;
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
void SimpleControl::publish_trajectory_setpoint(Eigen::Vector3d target, float yaw){
	px4_msgs::msg::TrajectorySetpoint msg{};
	msg.timestamp = int(this->get_clock()->now().nanoseconds() / 1000);

    msg.position[0] = target[0];
    msg.position[1] = target[1];
    msg.position[2] = target[2]; 

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

    RCLCPP_DEBUG(this->get_logger(), "Sending trajectory setpoint to UAV %i: at position %f, %f, %f and yaw: %f", this->robot_id, msg.position[0], msg.position[1], msg.position[2], msg.yaw);
    if(!this->m_output_file.empty())
    {
        this->save_trajectory_setpoint(msg);
    }

    trajectory_setpoint_publisher_->publish(msg);
}

/**
 * @brief Publish vehicle commands
 * @param command   Command code (matches VehicleCommand and MAVLink MAV_CMD codes)
 * @param param1    Command parameter 1
 * @param param2    Command parameter 2
 */
void SimpleControl::publish_vehicle_command(uint16_t command, float param1, float param2, uint8_t system_id)
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
    rclcpp::spin(std::make_shared<SimpleControl>());
    rclcpp::shutdown();
    return 0;
}