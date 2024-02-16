#!/bin/bash
interface="wlan0"

# Trick to handle specific right management on drones
touch /home/px4vision/experiments/current.pcapng
chmod 777 /home/px4vision/experiments/current.pcapng

# Starts captures
/home/px4vision/experiments/server 1 1 &
serverPID=$!
tshark -i $interface -w /home/px4vision/experiments/current.pcapng &
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

# Trick to handle specific right management on drones
cp /home/px4vision/experiments/current.pcapng /home/px4vision/current.pcapng
rm /home/px4vision/experiments/current.pcapng
cp /home/px4vision/current.pcapng /home/px4vision/experiments/current.pcapng
