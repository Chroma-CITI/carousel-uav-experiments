#!/bin/bash



# Check if env var ROS_WS is set.
if [[ -z "${ROS_WS}" ]]; then
    echo " Error ROS_WS not set. Please export ROS_WS with absolute path to the root of the ROS2 workspace. "
    exit 2
fi

source $ROS_WS/install/setup.bash

interface=`nmcli --get-values GENERAL.DEVICE,GENERAL.TYPE device show | awk '/^wifi/{print dev; next};{dev=$0};' | head -1`
drone_number=$1

ipServer="192.168.1.$drone_number"0 #Set the drone ip to the drone number multipled by 10
experience_name=$2
CT_delay_useconds=$3

# The controler is the same entity as the launcher
# This simplification is not possible otherwise
mkdir -p $ROS_WS/results/$experience_name/control

#mode Choregraphy 0 => TCP ... mode = 1 => UDP 


# Starts captures

tshark -i $interface -w $ROS_WS/results/$experience_name/control/capture.pcapng &
tshark_pid=$!

# Waits for passive trafic
sleep 10

# Starts choreography
echo "Starting choregraphy"
ros2 run offboard_control simple_control_pos --ros-args -p robot_id:=$drone_number -p takeoff_altitude:=2.0 -p omega:=0.4 --log-level SimpleControl:=debug  1>$ROS_WS/results/$experience_name/control/ros2_node.log 2>&1 &

# Execute choregraphy with no interference (15s)
sleep 15

# Starting network interference (15s)
echo "Starting network interference"
#"Saturated" trafic not control by any parameter for now
if [[ CT_delay_useconds != 0 ]]
then
$ROS_WS/networking/trafficGeneration/client 1000 $CT_delay_useconds $ipServer 1 > $ROS_WS/results/$experience_name/control/client.txt & 
interference_client_pid=$!
fi
sleep 15

# Stop interference
echo "Stop network interference"
if [[ CT_delay_useconds != 0 ]]
then
kill $interference_client_pid
fi
sleep 10

# Stops choreography
pkill simple_control_
echo " Choregraphy complete. "

# Stops captures
sleep 10
kill $tshark_pid
