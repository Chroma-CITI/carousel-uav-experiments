#!/bin/bash

## This script kills all the process involved in an experiment
## Should be prepared before starting an experiment and used as a red button


pkill simple_control_

ipDrone=192.168.1.10
ssh px4vision@192.168.1.10 "pkill drone_horloge.sh ; pkill tshark ; pkill server "
ssh px4vision@192.168.1.40 "pkill drone_horloge.sh ; pkill tshark ; pkill server "
pkill tshark
pkill ssh
pkill controle_pertur
pkill lancement*
pkill client
