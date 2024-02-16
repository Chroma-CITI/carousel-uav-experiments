#!/bin/bash
# Script servant à coordonnée les expériences
# Echange préalable de clefs publiques necessaire
# 
# Lance les scripts de chaque entité et récupère les données en local
#
# Dans cette expérience deux machines sont impliqués : un drone et 1 seul PC
# Le PC joue à la fois le rôle de controle (envoie les commandes) et celui de perturbation (iPerf3)

experience_name=$1

drone_number=$2

CT_msg_perSecond=$3


video=$4

while [ -z $experience_name ]
do
    echo "Entrer le nom de l'expérience"
    read experience_name
done

while [ -z $drone_number ]
do
    echo "Entrer le numero du drone"
    read drone_number
done

while [ -z $CT_msg_perSecond ]
do
    echo "Entrer le nombre de message par second"
    read CT_msg_perSecond
done

if [[ $CT_msg_perSecond != 0 ]]
then
    CT_delay_useconds=`echo "1000000*(1/$CT_msg_perSecond)" | bc -l`
else
    CT_delay_useconds=0
fi

mkdir $ROS_WS/results/$experience_name

mkdir $ROS_WS/results/$experience_name/control
mkdir $ROS_WS/results/$experience_name/pertubation
mkdir $ROS_WS/results/$experience_name/drone
rm -r $ROS_WS/results/$experience_name/rosbag

date > $ROS_WS/results/$experience_name/date.date



ip_drone="192.168.1.$drone_number"0 #Set the drone ip to the drone number multipled by 10
user_drone="px4vision"
path_script_drone="/home/px4vision/experiments/drone_horloge.sh"

function handle_ctrlc()
{
        pkill simple_control_
        pkill tshark
        ssh $user_drone@$ip_drone "pkill drone_horloge.sh ; pkill tshark ; pkill server "
        pkill client
        pkill controle_pertur
        pkill lancement*
        kill -2 `ps aux | grep "ros2 bag record" | head -n1 | cut -d ' ' -f4`        
        exit
}

trap handle_ctrlc SIGINT


#Capturing video
if [[ $video == 1 ]]
then
    python3 $ROS_WS/simpleVideoCapture/simpleCapture.py &
    videoCapture_pid=$!
fi 

## Launch rosbag recording
gnome-terminal -- ros2 bag record -o $ROS_WS/results/$experience_name/rosbag /px4_${drone_number}/mocap/odom /px4_${drone_number}/fmu/in/trajectory_setpoint /px4_${drone_number}/fmu/out/vehicle_local_position /px4_${drone_number}/fmu/out/vehicle_status /px4_${drone_number}/fmu/out/vehicle_attitude


## Connection to drone and launch of on-board experiment scripts 
echo " Connection to drone and launch of experiment scripts "
ssh $user_drone@$ip_drone $path_script_drone $experience_name & 
ssh_drone=$!

# launch the local control and interference script
$ROS_WS/networking/network-scripts/rotation_perturbation/controle_perturbation_horloge.sh $drone_number $experience_name $CT_delay_useconds &
controle_horloge=$!

# TODO : comment s'assurer de la fin de l'expérience : timer avec intervalle de garde ? 
sleep 65
# kill -7 $ssh_drone
# kill -7 $controle_horloge
sleep 2
if [[ $video == 1 ]]
then
    kill $videoCapture_pid
    mv $ROS_WS/simpleVideoCapture/filename.avi $ROS_WS/results/$experience_name/control/
fi 

# This line kills the ros2 bag recorder, this is dark magic don't try this at home
echo "Trying to kill ros2 bag record"
kill -2 `ps aux | grep "ros2 bag record" | head -n1 | cut -d ' ' -f4`

## Move data to results space and save data on the drone 
scp $user_drone@$ip_drone:/home/px4vision/experiments/$experience_name/drone/server.txt $ROS_WS/results/$experience_name/drone/
scp $user_drone@$ip_drone:/home/px4vision/experiments/$experience_name/drone/capture.pcapng $ROS_WS/results/$experience_name/drone/


echo " End of experiment $experience_name, ready to re-launch. "
