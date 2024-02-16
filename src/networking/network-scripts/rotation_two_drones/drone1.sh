#!/bin/bash
interface=wlan0
experience_name=$1

mkdir ~/experiments/$experience_name
mkdir ~/experiments/$experience_name/drone1

# Trick to handle specific right management on drones
touch /home/px4vision/experiments/$experience_name/drone1/capture.pcapng
chmod 777 /home/px4vision/experiments/$experience_name/drone1/capture.pcapng

# Starts captures

tshark -i $interface -w /home/px4vision/experiments/$experience_name/drone1/capture.pcapng &
tsharkPID=$!

# Waits for passive trafic
sleep 10
# Starts of choreography
sleep 15
# Start jamming
sleep 15
# Stop jammming
sleep 10
#Stop choreography
sleep 10

# Stop captures of received data (with no concurrent traffic)
kill $tsharkPID





