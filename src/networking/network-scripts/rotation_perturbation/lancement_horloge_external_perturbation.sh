#!/bin/bash
# Script servant à coordonnée les expériences
# Echange préalable de clefs publiques necessaire
# 
# Lance les scripts de chaque entité et récupère les données en local
#
# Dans cette expérience trois machines sont impliqués : un drone et 2 PC
# 1 pc : a priori celui qui lance ce script, envoie les commande au drone
# 1 autre pc : génère la perturbation vers le drone
# 1 drone : exécute la chorégraphie et reçoit le trafic de perturbation
experience_name=$1

while [ -z $experience_name ]
do
    echo "Entrer le nom de l'expérience"
    read experience_name
done

mkdir $ROS_WS/results/$experience_name

mkdir $ROS_WS/results/$experience_name/control
mkdir $ROS_WS/results/$experience_name/perturbation
mkdir $ROS_WS/results/$experience_name/drone

date > $ROS_WS/results/$experience_name/date.date


ROS_WS="/home/theotime/experiment_ws"

ip_drone="192.168.1.10"
user_drone="px4vision"
path_script_drone="/home/px4vision/experiments/drone_horloge.sh"

ip_interferer="192.168.1.17"
user_interferer="stage"
path_script_interferer="/home/stage/citi/perturbation_horloge.sh"

# Paramétrage du débit pour iperf
# debit="1M"

#Capturing video
if [[ $video == 1 ]]
then
    python3 $ROS_WS/simpleVideoCapture/simpleCapture.py &
    videoCapture_pid=$!
fi 


## Connection to drone and launch of on-board experiment scripts 
echo " Connection to drone and launch of experiment scripts "
ssh $user_drone@$ip_drone $path_script_drone $experience_name & 
ssh_drone=$!

## Connection to interfering machine and launch of experiments scripts
echo " Connection to interfering machine and launch of experiments scripts "
ssh $user_interferer@$ip_interferer $path_script_interferer $experience_name &
ssh_interferer=$!

$ROS_WS/networking/network-scripts/rotation_perturbation/controle_horloge.sh $experience_name &
controle_horloge=$!

# TODO : comment s'assurer de la fin de l'expérience : timer avec intervalle de garde ? 
sleep 65
#kill -7 $ssh_drone
kill -7 $controle_horloge
sleep 2
if [[ $video == 1 ]]
then
    kill $videoCapture_pid
    mv $ROS_WS/simpleVideoCapture/filename.avi $ROS_WS/results/$experience_name/control/
fi 

## Move data to results space and save data on the drone 
scp $user_drone@$ip_drone:/home/px4vision/experiments/$experience_name/drone/* $ROS_WS/results/$experience_name/drone
scp $user_interferer@$ip_interferer:/home/stage/citi/$experience_name/perturbation/* $ROS_WS/results/$experience_name/perturbation
# the control part should already be in $ROS_WS/results/$experience_name/control


echo " End of experiment $experience_name, ready to re-launch. "
