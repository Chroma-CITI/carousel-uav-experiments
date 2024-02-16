#!/bin/bash

# Extract average values of .data files
# works in pair with avg_extract.awk

# ./avg_extract.sh | awk -f avg_extract.awk


# Selecting which metric (.data files) should average be extracted from
# Selecting node of interest 

# TODO : allowing several nodes and metrics selection

#metric=debit_couche_4_perturbation
#node=drone_server

node=$1
metric=$2

# Selecting which experiments data are taken from

#for i in ../capture/xp_2* ../capture/1_06* ../capture/19_04*
for i in ../capture/*AD* 
do 
    # Extracting parameters and results
    # TODO : give the expected format for file naming
    senar=`echo -n $i | cut -d "/" -f 3`
    avg=`echo -n " " ; cat $i/$node/$metric.data | grep "#" | cut -d " " -f 2 | cut -f 2`
    
    etat=`echo $senar | cut -d "_" -f 3`
    pktSize=`echo $senar | cut -d "_" -f 4`
    timeIntPkt=`echo $senar | cut -d "_" -f 5`
    it=`echo $senar | cut -d "_" -f 6`
    
    echo $etat "" $pktSize " " $timeIntPkt " " $it " " $avg
done
