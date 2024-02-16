## Extract layer 4 sequence number of generated trafic 
## works in pair with tx_perte4_generateur.awk


# The output of seq4_list_generateur.awk have to be sorted out beacause of the way gawk stores value in associtative array
# Exemple of usage taken from traitement.sh

# awk -f seq4_list_generateur.awk $capture_dir/perturbation.txt | sort -V -k 2 | awk -f tx_perte4_generateur.awk > $capture_dir/tx_perte4_perturbation.data


BEGIN{}



{#CORE
    
    if ($1 == "[Time" && $2 == "since" && $3 == "reference"){
        date = $7
    }
    
    
    if ($1 == "0000" && $4 != "Differentiated"){
        split($18,tmp,".")
        seq=tmp[1]        
        seqTab[seq]=date


    }
    
    
}#ENDCORE



END{
    
    for (i in seqTab) {
            printf ("%d %s\n",i,seqTab[i]) 
        
    }
    
}
