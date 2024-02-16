## Computes layer 4 loss rate based sequence number of generated trafic 
## works in pair with tx_perte4_generateur.awk


# The output of seq4_list_generateur.awk have to be sorted out beacause of the way gawk stores value in associtative array
# Exemple of usage taken from traitement.sh

# awk -f seq4_list_generateur.awk $capture_dir/perturbation.txt | sort -V -k 2 | awk -f tx_perte4_generateur.awk > $capture_dir/tx_perte4_perturbation.data


BEGIN{
    
    total=0
    seqPrev=-1
    timeStep=1.0
    timePrev=0.0
}


{
    seq=$1
    date=$2

    sliceTotal++
    total++

    if (seq - seqPrev != 1 ){
        missing+= (seq - seqPrev)-1
        missingTotal+=missing
        #print $0 " missing " (seq - seqPrev)-1
    }
    
    if (date-datePrev >= timeStep){
        printf("%s\t%f\n",date,missing/(missing+sliceTotal))
        missing=0
        sliceTotal=0
    }

    
    seqPrev=seq
    datePrev=date

    
}


END{
    
    printf("# missing %d\t total %d\n",missingTotal,total)
    printf("# taux de perte %f\n",missingTotal/(total+missing))
    
}
