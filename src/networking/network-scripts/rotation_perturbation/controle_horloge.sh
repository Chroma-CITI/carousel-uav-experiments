#!/bin/bash

# Check if env var ROS_WS is set.
if [[ -z "${ROS_WS}" ]]; then
    echo " Error ROS_WS not set. Please export ROS_WS with absolute path to the root of the ROS2 workspace. "
    exit 2
fi

experience_name=$1

# The controler is the same entity as the launcher
# This simplification is not possible otherwise
mkdir $ROS_WS/results/$experience_name/control

source $ROS_WS/install/setup.bash

interface="wlp0s20f3"
#mode Choregraphy 0 => TCP ... mode = 1 => UDP 

# Starts captures
touch $ROS_WS/results/$experience_name/control/capture.pcapng
chmod 777 $ROS_WS/results/$experience_name/control/capture.pcapng

tshark -i $interface -w $ROS_WS/results/$experience_name/control/capture.pcapng &
tshark_pid=$!

# Waits for passive trafic
sleep 10

# Starts choreography
ros2 run offboard_control simple_control_pos --ros-args -p robot_id:=1 -p takeoff_altitude:=2.0 -p omega:=0.8 --log-level SimpleControl:=debug  1>./$experience_name/control/ros2_node.log 2>&1 &

# Execute choregraphy with no interference (15s)
sleep 15

# Starting network interference (15s)
sleep 15

# Stop interference
# kill $interference_client_pid
sleep 10

# Stops choreography
pkill simple_control_
echo " Choregraphy complete. "

# Stops captures
sleep 10
kill $tshark_pid
