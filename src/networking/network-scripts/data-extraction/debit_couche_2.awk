# Computes layer 2 throughput
# Has to be executed on -V versions of captures

BEGIN{
    
    acc=0
    timeStep=1.0
    timePrev=0.0
    
    timeStartExp=10
    timeEndExp=120
    
}



    
{ ## CORE

        
        if ($1 == "[Time" && $2 == "since" && $3 == "reference"){
        # datePrev=date    
            date = $7
                if (first==1){
                    datePrev = $7
                    first=0
                }
        }
        
        
        if ( date > timeStartExp && date < timeEndExp ){

            if ($1 == "Frame" && $2 =="Length:"){
                    acc+=$3
                    accTotal+=$3
            }
            
            if (date - timePrev >= timeStep){
                printf("%s\t%f\n",date, acc/(date-timePrev))
                timePrev=date 
                acc=0
                
            }
        
        }#end intervalle 10
    
    
}#CORE


END{
    
    printf("# %s\t%f\n",date,accTotal/((timeEndExp-(timeStartExp+1))))
}
