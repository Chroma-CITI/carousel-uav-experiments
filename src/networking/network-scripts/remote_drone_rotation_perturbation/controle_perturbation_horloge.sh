#!/bin/bash

# Check if env var ROS_WS is set.
if [[ -z "${ROS_WS}" ]]; then
    echo " Error ROS_WS not set. Please export ROS_WS with absolute path to the root of the ROS2 workspace. "
    exit 2
fi

source $ROS_WS/install/setup.bash

interface="wlan0"
ipServer=$1
#mode Choregraphy 0 => TCP ... mode = 1 => UDP 

# Starts captures
tshark -i $interface -w /home/px4vision/experiments/current.pcapng &
tshark_pid=$!



# Waits for passive trafic
sleep 10

# Starts choreography
# TODO : check that before testing
# # ros2 run offboard_control simple_control_pos --ros-args -p robot_id:=1 -p takeoff_altitude:=2.0 -p omega:=0.8 --log-level SimpleControl:=debug  1>$ROS_WS/ros2_node.log 2>&1 &

# Execute choregraphy with no interference (15s)
sleep 15

# Starting network interference (15s)
echo "Starting network interference"
#"Saturated" trafic not control by any parameter for now
$ROS_WS/networking/trafficGeneration/client 1000 0 $ipServer 1 > /dev/null & 
interference_client_pid=$!
sleep 15

# Stop interference
kill $interference_client_pid
sleep 10

# Stops choreography
pkill simple_control_
echo " Choregraphy complete. "

# Stops captures
sleep 10
kill $tshark_pid
