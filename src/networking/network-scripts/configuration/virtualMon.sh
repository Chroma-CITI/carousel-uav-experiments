#!/bin/bash

# Setting up a virtual network interface in monitor mode
# The name of the created interface can be change for convinience 

virtualName="wlp2s0Mon"

iw phy phy0 interface add $virtualName type monitor
ifconfig $virtualName up
