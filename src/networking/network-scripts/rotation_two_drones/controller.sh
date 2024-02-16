#!/bin/bash

# TODO: ONCE THIS WORKS TRY TO FIND A WAY TO MAKE IT WITHOUT sleep??

# Check if env var ROS_WS is set.
if [[ -z "${ROS_WS}" ]]; then
    echo " Error ROS_WS not set. Please export ROS_WS with absolute path to the root of the ROS2 workspace. "
    exit 2
fi

source $ROS_WS/install/setup.bash

interface=`nmcli --get-values GENERAL.DEVICE,GENERAL.TYPE device show | awk '/^wifi/{print dev; next};{dev=$0};' | head -1`

# Recuperer les parametres
drone1_number=$1
drone2_number=$2
experience_name=$3
CT_delay_useconds=$4

mkdir -p $ROS_WS/results/$experience_name/control

#mode Choregraphy 0 => TCP ... mode = 1 => UDP 

# Starts captures of sending data stream (sent to both drones) *useful to calculate metrix after experiment. 
tshark -i $interface -w $ROS_WS/results/$experience_name/control/capture.pcapng &
tshark_pid=$!

# Waits for passive trafic
sleep 10

# Starts choreography in both drones --> this info is being captured with prev command
#TODO some parameters of ros to fly the drone or to change its coreography might be easily changed to observe differences. 
echo "starting cmd drone 1"
ros2 run offboard_control simple_control_pos --ros-args -p robot_id:=$drone1_number -p takeoff_altitude:=2.0 -p omega:=0.4 --log-level SimpleControl:=debug  1>$ROS_WS/results/$experience_name/control/ros2_node_drone1.log 2>&1 &

echo "starting cmd drone 2"
ros2 run offboard_control simple_control_pos --ros-args -p robot_id:=$drone2_number -p takeoff_altitude:=2.0 -p omega:=0.4 --log-level SimpleControl:=debug  1>$ROS_WS/results/$experience_name/control/ros2_node_drone2.log 2>&1 &

 

#CHOICE OF DESIGN: EITHER USE THESE TWO OF THIS LINES (CREATE 2 PROCESSES) TO START 2 DRONES OR DO IT WITH JUST 1 PROCESS 

# Execute choregraphy with no interference (15s)
sleep 15

# Starting network interference (15s) ONLY TO DRONE 2!!!

ip_drone_2="192.168.1.$drone2_number"0
#The two number parameters are: packet size () and period (us). TODO: we could want to ask this paramaters by cmd other than change them manually in the script
if [[ $CT_delay_useconds != 0 ]]
then
    echo "Starting concurrent traffic, causing network interference"
    $ROS_WS/networking/trafficGeneration/client 1000 $CT_delay_useconds $ip_drone_2 1 > $ROS_WS/results/$experience_name/control/client.txt &
    interference_client_pid=$!
fi
sleep 15

# Stop interference
if [[ $CT_delay_useconds != 0 ]]
then
    echo "Stopping concurrent traffic"
    kill $interference_client_pid
fi
sleep 10

# Stops choreography
pkill simple_control_
echo " Choregraphy complete. "

# Stops captures of sending traffic
sleep 10
kill $tshark_pid
