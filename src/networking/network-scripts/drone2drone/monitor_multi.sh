#!/bin/bash

# Assume the NIC is already configured in monitor mode
interface=wlo1mon

# Starts captures
tshark -i $interface -w current.pcapng &
tsharkPID=$!
sleep 5

# Starts trafic generation
sleep 30
# Stop trafic
sleep 5

# Stop capture
kill $tsharkPID
