#!/bin/bash
interface=wlan0

touch /home/px4vision/experiments/current.pcapng
chmod 777 /home/px4vision/experiments/current.pcapng

# Starts captures and the server
# The second parameters of the server is the report delay (not so important for now on)
tshark -i $interface -w /home/px4vision/experiments/current.pcapng &
tsharkPID=$!

/home/px4vision/experiments/server $1 1 &
serverPID=$!

sleep 5 

# Starts trafic generation
sleep 30

# Stop trafic
kill $serverPID
sleep 5

# Stop capture
kill $tsharkPID

