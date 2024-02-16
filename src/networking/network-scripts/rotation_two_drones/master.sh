#!/bin/bash
# Script servant à coordonnée les expériences
# Echange préalable de clefs publiques necessaire
# 
# Lance les scripts de chaque entité et récupère les données en local
#
# Dans cette expérience: 2 drones et 1 seul PC qui a à la fois le rôle de controle (envoie les commandes) et celui de perturbation (iPerf3)

experience_name=$1
drone1_number=$2
drone2_number=$3
CT_msg_perSecond=$4
video=$5

while [ -z $experience_name ]
do
    echo "Entrer le nom de l'expérience"
    read experience_name
done


while [ -z $drone1_number ]
do
    echo "Entrer le numero du drone 1"
    read drone1_number
done

while [ -z $drone2_number ]
do
    echo "Entrer le numero du drone 2 (recevant le trafic concurrent)"
    read drone2_number
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
mkdir $ROS_WS/results/$experience_name/drone1
mkdir $ROS_WS/results/$experience_name/drone2

date > $ROS_WS/results/$experience_name/date.date

ip_drone_1="192.168.1.$drone1_number"0
path_script_drone_1="/home/px4vision/experiments/drone1.sh"

ip_drone_2="192.168.1.$drone2_number"0
path_script_drone_2="/home/px4vision/experiments/drone2_jamm.sh"

user_drone="px4vision"

function handle_ctrlc()
{
        pkill simple_control_
        pkill tshark
        ssh $user_drone@$ip_drone_1 "pkill drone1.sh ; pkill tshark ; pkill server "
        ssh $user_drone@$ip_drone_2 "pkill drone2_jamm.sh ; pkill tshark ; pkill server "
        pkill client
        pkill controle_pertur
        pkill lancement*
        kill -2 `ps aux | grep "ros2 bag record" | head -n1 | cut -d ' ' -f4`        
        exit
}

trap handle_ctrlc SIGINT

#Capturing video - only activated if you put a second param to 1. 
if [[ $video == 1 ]]
then
    python3 $ROS_WS/simpleVideoCapture/simpleCapture.py &
    videoCapture_pid=$!
fi 

## Launch rosbag recording
gnome-terminal -- ros2 bag record -o $ROS_WS/results/$experience_name/rosbag /px4_${drone1_number}/mocap/odom /px4_${drone1_number}/fmu/in/trajectory_setpoint /px4_${drone1_number}/fmu/out/vehicle_local_position /px4_${drone1_number}/fmu/out/vehicle_status /px4_${drone1_number}/fmu/out/vehicle_attitude /px4_${drone2_number}/mocap/odom /px4_${drone2_number}/fmu/in/trajectory_setpoint /px4_${drone2_number}/fmu/out/vehicle_local_position /px4_${drone2_number}/fmu/out/vehicle_status /px4_${drone2_number}/fmu/out/vehicle_attitude

# # # ## Connection to drone and launch of on-board experiment scripts 
echo " Connection to drone and launch of experiment scripts "
ssh $user_drone@$ip_drone_1 $path_script_drone_1 $experience_name & 
ssh_drone=$!

# # # ## Connection to drone and launch of on-board experiment scripts 
echo " Connection to drone and launch of experiment scripts "
ssh $user_drone@$ip_drone_2 $path_script_drone_2 $experience_name & 
ssh_drone=$!


#ROS command and experiment start with controller.sh. Parameter 1 is ipdrone2. Parameter 2 is experience_name.
$ROS_WS/networking/network-scripts/rotation_two_drones/controller.sh $drone1_number $drone2_number $experience_name $CT_delay_useconds & 
controller=$!


# TODO : comment s'assurer de la fin de l'expérience : timer avec intervalle de garde ?  --> Send a message from controller.sh to master.sh when the experiment is finished??
#sleep during capturing
sleep 65

#kill -7 $ssh_drone
kill -7 $controller
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
scp $user_drone@$ip_drone_2:/home/px4vision/experiments/$experience_name/drone2/server.txt $ROS_WS/results/$experience_name/drone2/

scp $user_drone@$ip_drone_1:/home/px4vision/experiments/$experience_name/drone1/capture.pcapng $ROS_WS/results/$experience_name/drone1/ &
scp $user_drone@$ip_drone_2:/home/px4vision/experiments/$experience_name/drone2/capture.pcapng $ROS_WS/results/$experience_name/drone2/

echo " End of experiment $experience_name, ready to re-launch. "


