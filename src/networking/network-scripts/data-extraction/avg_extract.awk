# Extract average values of .data files
# works in pair with avg_extract.awk

# ./avg_extract.sh | awk -f avg_extract.awk

BEGIN{}


{#CORE
    
    etat=$1
    pktSize=$2
    pktIntTime=$3
    it=$4
    
    val=$5
    
    tab[etat][pktSize][pktIntTime][it]=val
    
}#END CORE



END{
        for (_etat in tab){
                for (_size in tab[_etat]){
                        for (_time in tab[_etat][_size]){
                            for (_it in tab[_etat][_size][_time]){
                                   # printf (" %s %d %d %d : %d\n",_etat,_size,_time,_it,tab[_etat][_size][_time][_it])
                                    avg[_etat][_size][_time]+=tab[_etat][_size][_time][_it]
                                    count[_etat][_size][_time]++
                            }
                            avg[_etat][_size][_time]=avg[_etat][_size][_time]/count[_etat][_size][_time]
                        }
                }
            
        }

        printf("etat\tpktSize\tdelay\tavg\n")
        for (_etat in avg){
                for (_size in avg[_etat]){
                        for (_time in avg[_etat][_size]){
                            printf ("%s\t%d\t%d\t%f\n",_etat,_size,_time,avg[_etat][_size][_time])
                        }
                }
            
        }

    
}
