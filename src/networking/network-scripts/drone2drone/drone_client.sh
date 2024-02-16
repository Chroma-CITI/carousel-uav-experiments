#!/bin/bash
interface=wlan0

touch /home/px4vision/experiments/current.pcapng
chmod 777 /home/px4vision/experiments/current.pcapng

# Starts captures
tshark -i $interface -w /home/px4vision/experiments/current.pcapng &
tsharkPID=$!
sleep 5 

# Starts trafic generation
/home/px4vision/experiments/client $1 $2 $3 $4 &
clientPID=$!
sleep 30

# Stop trafic
kill -7 $clientPID
sleep 5

# Stop capture
kill $tsharkPID
