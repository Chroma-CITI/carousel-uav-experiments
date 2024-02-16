#!/bin/bash

source $ROS_WS/install/setup.bash

# interface=`nmcli --get-values GENERAL.DEVICE,GENERAL.TYPE device show | awk '/^wifi/{print dev; next};{dev=$0};' | head -1`
interface=enxcc96e5c8d3ed

# Recuperer les parametres
experience_name=$1
drone1_number=$2
drone2_number=$3
drone3_number=$4

while [ -z $experience_name ]
do
    echo "Entrer le nom de l'expérience"
    read experience_name
done


while [ -z $drone1_number ]
do
    echo "Entrer le numero du leader"
    read drone1_number
done

while [ -z $drone2_number ]
do
    echo "Entrer le numero du follower 1"
    read drone2_number
done

while [ -z $drone3_number ]
do
    echo "Entrer le numero du follower 2"
    read drone3_number
done

mkdir $ROS_WS/results/$experience_name

mkdir $ROS_WS/results/$experience_name/control
mkdir $ROS_WS/results/$experience_name/leader
mkdir $ROS_WS/results/$experience_name/follower1
mkdir $ROS_WS/results/$experience_name/follower2

date > $ROS_WS/results/$experience_name/date.date

ip_drone_1="192.168.0.161"
ip_drone_2="192.168.0.153"
ip_drone_3="192.168.0.49"

user_drone="px4vision"
drone_interface="wlan0"

function handle_ctrlc()
{
    echo "EMERGENCY EXIT, closing all cleanly"

    # This line kills the ros2 bag recorder, this is dark magic don't try this at home
    echo "Trying to kill ros2 bag record"
    kill -2 `ps aux | grep "ros2 bag record" | head -n1 | cut -d ' ' -f4`

    # kill all
    echo "Trying to kill tshark, simple_control, ssh sessions"
    pkill tshark
    ssh $user_drone@$ip_drone_1 "pkill tshark"
    ssh $user_drone@$ip_drone_2 "pkill tshark; pkill uwb_ros_node"
    ssh $user_drone@$ip_drone_3 "pkill tshark; pkill uwb_ros_node"
    kill $ssh_drone1
    kill $ssh_drone2
    kill $ssh_drone3
    pkill uwb_formation
    exit
}

trap handle_ctrlc SIGINT

# ssh $user_drone@$ip_drone_1 "source /home/px4vision/colcon_ws/install/setup.bash && ros2 run uwb_ros uwb_ros_node --ros-args -r __ns:=/px4_$drone1_number" &
ssh $user_drone@$ip_drone_2 "source /home/px4vision/colcon_ws/install/setup.bash && ros2 run uwb_ros uwb_ros_node --ros-args -r __ns:=/px4_$drone2_number" &
ssh $user_drone@$ip_drone_3 "source /home/px4vision/colcon_ws/install/setup.bash && ros2 run uwb_ros uwb_ros_node --ros-args -r __ns:=/px4_$drone3_number" &

## Launch rosbag recording
gnome-terminal -- ros2 bag record -o $ROS_WS/results/$experience_name/rosbag /px4_${drone1_number}/mocap/odom /px4_${drone1_number}/fmu/in/trajectory_setpoint /px4_${drone1_number}/fmu/out/vehicle_local_position /px4_${drone1_number}/fmu/out/vehicle_status /px4_${drone1_number}/fmu/out/vehicle_attitude /px4_${drone2_number}/mocap/odom /px4_${drone2_number}/fmu/in/trajectory_setpoint /px4_${drone2_number}/fmu/out/vehicle_local_position /px4_${drone2_number}/fmu/out/vehicle_status /px4_${drone2_number}/fmu/out/vehicle_attitude /px4_${drone1_number}/uwb /px4_${drone2_number}/uwb /px4_${drone3_number}/mocap/odom /px4_${drone3_number}/fmu/in/trajectory_setpoint /px4_${drone3_number}/fmu/out/vehicle_local_position /px4_${drone3_number}/fmu/out/vehicle_status /px4_${drone3_number}/fmu/out/vehicle_attitude /px4_${drone3_number}/uwb

# # # ## Connection to drone and launch of tshark 
echo " Connection to drone $drone1_number  and launch of tshark "
ssh $user_drone@$ip_drone_1 "echo 'drone leader connected' && mkdir -p /home/px4vision/experiments/$experience_name/leader && tshark -i $drone_interface -w /home/px4vision/experiments/$experience_name/leader/capture.pcapng" &
ssh_drone1=$!

# # # ## Connection to drone and launch of tshark 
echo " Connection to drone $drone2_number and launch of tshark "
ssh $user_drone@$ip_drone_2 "echo 'drone follower 1 connected' && mkdir -p /home/px4vision/experiments/$experience_name/follower1 && tshark -i $drone_interface -w /home/px4vision/experiments/$experience_name/follower1/capture.pcapng" &
ssh_drone2=$!

# # # ## Connection to drone and launch of tshark 
echo " Connection to drone $drone3_number and launch of tshark "
ssh $user_drone@$ip_drone_3 "echo 'drone follower 2 connected' && mkdir -p /home/px4vision/experiments/$experience_name/follower2 && tshark -i $drone_interface -w /home/px4vision/experiments/$experience_name/follower2/capture.pcapng" &
ssh_drone3=$!

tshark -i $interface -w $ROS_WS/results/$experience_name/control/capture.pcapng &
tshark_pid=$!

read -p "Press enter to start uwb followers"


#ROS command and experiment start with controller.sh. Parameter 1 is ipdrone2. Parameter 2 is experience_name.
echo "starting autonomous follower UWB"
ros2 run offboard_control uwb_formation --ros-args -p robot_id:=$drone2_number --log-level SimpleControl:=debug 1>$ROS_WS/results/$experience_name/control/ros2_node_follower_1.log 2>&1 &
ros2 run offboard_control uwb_formation --ros-args -p robot_id:=$drone3_number --log-level SimpleControl:=debug 1>$ROS_WS/results/$experience_name/control/ros2_node_follower_2.log 2>&1 &

read -p "Press enter to end experiment"

sleep 2

# This line kills the ros2 bag recorder, this is dark magic don't try this at home
echo "Trying to kill ros2 bag record"
kill -2 `ps aux | grep "ros2 bag record" | head -n1 | cut -d ' ' -f4`

# kill all
echo "Trying to kill tshark, simple_control, ssh sessions"
pkill tshark
ssh $user_drone@$ip_drone_1 "pkill tshark"
ssh $user_drone@$ip_drone_2 "pkill tshark; pkill uwb_ros_node"
ssh $user_drone@$ip_drone_3 "pkill tshark; pkill uwb_ros_node"

kill $ssh_drone1
kill $ssh_drone2
kill $ssh_drone3

pkill uwb_formation

# Copy the pcapng files to the results folder
echo "Copying pcapng files to results folder"
scp $user_drone@$ip_drone_1:/home/px4vision/experiments/$experience_name/leader/capture.pcapng $ROS_WS/results/$experience_name/leader/ &
scp $user_drone@$ip_drone_2:/home/px4vision/experiments/$experience_name/follower1/capture.pcapng $ROS_WS/results/$experience_name/follower1/ &
scp $user_drone@$ip_drone_3:/home/px4vision/experiments/$experience_name/follower2/capture.pcapng $ROS_WS/results/$experience_name/follower2/



