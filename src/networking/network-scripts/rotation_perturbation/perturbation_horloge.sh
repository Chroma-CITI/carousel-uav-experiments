#!/bin/bash

# Check if env var ROS_WS is set.
if [[ -z "${ROS_WS}" ]]; then
    echo " Error ROS_WS not set. Please export ROS_WS with absolute path to the root of the ROS2 workspace. "
    exit 2
fi

interface="wlp2s0"
ipServer=$1
experience_name=$2


mkdir ./$experience_name
mkdir ./$experience_name/perturbation



#mode Choregraphy 0 => TCP ... mode = 1 => UDP 

# Starts captures
touch ./$experience_name/perturbation/capture.pcapng
chmod 777 ./$experience_name/perturbation/capture.pcapng
tshark -i $interface -w ./$experience_name/perturbation/capture.pcapng &
tshark_pid=$!
# Waits for passive trafic
sleep 10

# Starts choreography
# Execute choregraphy with no interference (15s)
sleep 15

# Starting network interference (15s)
# echo "Starting network interference"
 $ROS_WS/networking/trafficGeneration/client 1000 0 $ipServer 1 > ./$experience_name/perturbation/client.txt & 
interference_client_pid=$!
sleep 15

# Stop interference
kill $interference_client_pid
sleep 10
# Stops choreography


# Stops captures
sleep 10
kill $tshark_pid
