#!/bin/bash

# Launch script are exemple of how to lead automated experiments
# This scenario involves 4 agents
#
# UAV : drone_server
# UAV : drone_client
# The PC sending orders (choreography) to the drone : controle
# A PC with a NIC in monitor mode

# In this exemple there is no choreography hence no control agent
# drone client send a configurable trafic to drone_server
# The trafic is generated by a custom trafic generator provided in this git

# This script triggers each agent "mission" by calling specific scripts
# Then retreives the captured network trafic in pcap files
# The locations of these scripts has to be known
# Exemple of missions script are also given in this git

# For the drone captured file are renamed and store
# The connexion might be very lossy so the data transfert is done afterward



experience_name=$1

## The trafic can be configurated while calling the script or in an interactive manner
pktSize=$2
delay=$3

while [ -z $experience_name ]
do
    echo "Enter experiment name"
    read experience_name
done

while [ -z $pktSize ]
do
    echo "Enter packet size"
    read pktSize
done

while [ -z $delay ]
do
    echo "Enter interpacket delay µseconds"
    read delay
done

## IP and user name needed for SSH connections 
## This script suppose the existance two networks 
## 192.168.1.0 is Wi-Fi (citidrone)
## 192.168.2.0 is wired
ip_controle="192.168.2.15"
user_controle="chroma"

ip_monitor="192.168.2.1"
user_monitor="stage"

ip_drone_client="192.168.1.10"
ip_drone_server="192.168.1.40"
user_drone="px4vision"


## Creating directories to retreive and store data
## Processing scripts assume this directory architecture

echo "Creating the file tree structure"
 mkdir $experience_name
 mkdir -p $experience_name/controle
 mkdir -p $experience_name/monitor
 mkdir -p $experience_name/drone_client
 mkdir -p $experience_name/drone_server
 mkdir -p $experience_name/perturbation


# Configuring transport layer for the generated trafic 
mode=1  # 0 for TCP and 1 for UDP, server and client have to be configured the same way

## Connexion et lancement des script d'expérience
echo " SSH connections and experiment start "
#ssh $user_controle@$ip_controle "bash -l /home/chroma/experiments/controle_multi.sh" &

ssh $user_monitor@$ip_monitor /home/stage/drone/monitor_multi.sh &
sshmon=$!
ssh $user_drone@$ip_drone_client /home/px4vision/experiments/drone_client.sh $pktSize $delay $ip_drone_server $mode & 
sshclient=$!
ssh $user_drone@$ip_drone_server /home/px4vision/experiments/drone_server.sh $mode & 
sshserv=$!

## This time is calculated regarding the mission and might need to be changed
sleep 55 

## SSH sessions should close themselve ...
kill $sshmon
kill $sshclient
kill $sshserv

## Retreiving data
echo "Data retreiving"
echo -e "\t Retreives data from control"
# # # scp $user_controle@$ip_controle:/home/chroma/experiments/current.pcapng $experience_name/controle/capture.pcapng
echo -e "\t Retreives data from monitor"
scp $user_monitor@$ip_monitor:/home/stage/drone/current.pcapng $experience_name/monitor/capture.pcapng

# Plutot que de récupérer les donnée du drone, on les laisse sur le disque pour les récupérer plus tard
echo -e "\t Moving data from client drone"
ssh $user_drone@$ip_drone_client mv /home/px4vision/experiments/current.pcapng /home/px4vision/experiments/$experience_name\_drone_client.pcapng
echo -e "\t Moving data from server drone"
ssh $user_drone@$ip_drone_server mv /home/px4vision/experiments/current.pcapng /home/px4vision/experiments/$experience_name\_drone_server.pcapng

echo -e "\t Saving all experiments data"
mv current.pcapng $experience_name/perturbation/capture.pcapng

mv $experience_name /home/tarrabal/capture

echo "Experiment is over, ready to start again "
