#!/bin/bash
interface=wlan0
experience_name=$1

mkdir ~/experiments/$experience_name
mkdir ~/experiments/$experience_name/drone

# Trick to handle specific right management on drones
touch /home/px4vision/experiments/$experience_name/drone/capture.pcapng
chmod 777 /home/px4vision/experiments/$experience_name/drone/capture.pcapng

# Starts captures
/home/px4vision/experiments/server 1 1 > /home/px4vision/experiments/$experience_name/drone/server.txt  &
serverPID=$!
tshark -i $interface -w /home/px4vision/experiments/$experience_name/drone/capture.pcapng &
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

# Stop captures
kill $serverPID # Server can be killed anytime after the jamming has ended
kill $tsharkPID
