#!/bin/bash

# Configure a Wi-Fi card in ad-hoc mode

# Following commands needs root privileges


# /!\ IP adress had to be changed on each network node
ip=192.168.1.1

interface="wlp2s0"

# Arbitrary channel choice
channel=2
essid="HADHOC"

sudo service network-manager stop
sudo rfkill unblock wlan
sudo iwconfig $interface mode ad-hoc 
sudo iwconfig $interface essid $essid
sudo iwconfig $interface channel $channel
sudo iwconfig $interface enc off 
sudo ifconfig $interface $ip
sudo ifconfig $interface up

