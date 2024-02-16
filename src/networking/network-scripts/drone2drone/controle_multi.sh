#!/bin/bash


# Starts captures
tshark -i $interface -w current.pcapng &
tsharkPID=$!
sleep 5
# Takes off
### Here goes the script to take off
# Waits for passive trafic
sleep 10
# Starts of choreography
### Here goes the choreography script
sleep 10
# Start perturbation
sleep 10
# Stop choreography
### Here goes the killing command of the choreography script if needed
sleep 10
# Stop perturbation

# Waits for passive trafic
sleep 10
# Landing
### Here goes the script to land
sleep 5

# Stop captures
kill $tsharkPID
