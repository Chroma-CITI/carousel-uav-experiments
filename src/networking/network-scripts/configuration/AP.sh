#!/bin/bash

# Turns a Linux system in a Wi-Fi acces point
# Needs a correct hostapd.conf

interface="wlp0s20f3"

sudo rfkill unblock wlan
sudo chmod 777 /var/lib/dhcp/dhcpd.leases
sudo ifconfig $interface 192.168.1.11
sudo dhcpd
sudo hostapd -i $interface /etc/hostapd/hostapd.conf
