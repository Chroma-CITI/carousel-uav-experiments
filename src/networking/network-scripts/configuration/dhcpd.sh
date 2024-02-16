#!/bin/bash

sudo ifconfig enp0s31f6 192.168.1.1
sudo chmod 777 /var/lib/dhcp/dhcpd.leases
sudo dhcpd
