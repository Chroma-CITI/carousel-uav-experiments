!/bin/bash
interface=wlan0
experience_name=$1

mkdir ~/experiments/$experience_name
mkdir ~/experiments/$experience_name/drone2


# Trick to handle specific right management on drones
touch /home/px4vision/experiments/$experience_name/drone2/capture.pcapng
chmod 777 /home/px4vision/experiments/$experience_name/drone2/capture.pcapng

# Starts captures

#This is the capturing of concurrent traffic in drone2 to which it is addressed. 
/home/px4vision/experiments/server 1 1 > /home/px4vision/experiments/$experience_name/drone2/server.txt  &
serverPID=$!

tshark -i $interface -w /home/px4vision/experiments/$experience_name/drone2/capture.pcapng &
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

# Stop captures of received data (with concurrent traffic)
kill $serverPID # Server can be killed anytime after the jamming has ended
kill $tsharkPID


