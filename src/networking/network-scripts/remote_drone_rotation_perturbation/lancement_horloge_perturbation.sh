#!/bin/bash
# Script servant à coordonnée les expériences
# Echange préalable de clefs publiques necessaire
# 
# Lance les scripts de chaque entité et récupère les données en local
#
# Dans cette expérience deux machines sont impliqués : un drone et 1 seul PC
# Le PC joue à la fois le rôle de controle (envoie les commandes) et celui de perturbation (iPerf3)

experience_name=$1
video=$2

while [ -z $experience_name ]
do
    echo "Entrer le nom de l'expérience"
    read experience_name
done

date > $i.date

ip_drone_control="192.168.1.10"
ip_drone_dancer="192.168.1.40"

user_drone="px4vision"

path_script_drone="/home/px4vision/experiments"


## Create temporary folders to hold experiment data
echo " Creating file tree "
mkdir tmp
mkdir ./tmp/$experience_name

#Capturing video
if [[ $video == 1 ]]
then
    python3 /home/tarrabal/camera/simpleCapture/simpleCapture.py &
    videoCapture_pid=$!
fi 

## Connection to drone and launch of on-board experiment scripts 
echo " Connection to drone and launch of experiment scripts "


ssh $user_drone@$ip_drone_dancer $path_script_drone/drone_horloge.sh & 
ssh_dancer=$!

ssh $user_drone@$ip_drone_control $path_script_drone/controle_pertubation_horloge.sh $ip_drone_dancer & 
ssh_control=$!



# TODO : comment s'assurer de la fin de l'expérience : timer avec intervalle de garde ? 
sleep 65
#kill -7 $ssh_drone

sleep 2
if [[ $video == 1 ]]
then
    kill $videoCapture_pid
fi 

## Move data to results space and save data on the drone 
mv $ROS_WS/ros2_node.log ./tmp/$experience_name/ros2_node.log

echo -e "\t Déplacement drone"
ssh $user_drone@$ip_drone_dancer cp /home/px4vision/experiments/current.pcapng /home/px4vision/experiments/$experience_name.pcapng
ssh $user_drone@$ip_drone_control cp /home/px4vision/experiments/current.pcapng /home/px4vision/experiments/$experience_name.pcapng

mv ./tmp/$experience_name $ROS_WS/results/$experience_name/
mv $i.date $ROS_WS/results/$experience_name/

echo " End of experiment $experience_name, ready to re-launch. "
