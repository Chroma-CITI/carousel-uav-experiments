
# computes layer 4 throughput (used for the generated trafic)
# used on short version of capture (without -V)

# TODO : Does it work with iperf ?
 


BEGIN{
    
    acc=0
    timeStep=1.0
    timePrev=0.0
    
    timeStartExp=10
    timeEndExp=120
    
}


{ ## CORE
    
    date = $2

        if ( date > timeStartExp && date < timeEndExp ){

        split($11,tmp,"=")
        len=tmp[2]
        acc+=len
        accTotal+=len
        elapsedTime = date - timePrev
        
        if ( elapsedTime >= timeStep){

            printf("%s\t%f\n",date, acc/(date-timePrev))
            timePrev=date 
            acc=0
            
        }
        
    } # end intervalle
    
    
}#CORE



END{
    printf("# %s\t%f\n",date,accTotal/((timeEndExp-(timeStartExp+1))))
    
}
