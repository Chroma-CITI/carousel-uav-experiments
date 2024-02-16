
## Compute the channel occupation rate
## Has to be executed on -V versions of captures
## Need Wi-Fi headers, hence monitor capture files


BEGIN{
    
    busyTime=0
    timeStep=1.0
    timePrev=0.0
    
    timeStartExp=11
    timeEndExp=13
    
}



    
{ ## CORE
    
        if ($1 == "[Time" && $2 == "since" && $3 == "reference"){
        # datePrev=date
            date = $7
                if (first==1){
                    timePrev = $7
                    first=0
                }
        }
        
        if ( date > timeStartExp && date < timeEndExp ){
            if ($1 == "[Duration:") {#&& $2 =="Length:"){
                        print $0 " : " date
                        split($2,tmp,"µ")
                        busyTime+=tmp[1]
                        busyTotal+=tmp[1]
                        #printf ("date : %s busyTime : %f busyTotal %f \n",date, busyTime/1000000,busyTotal/1000000)
                         
            }
                
                if (date - timePrev >= timeStep){
                    
                    
                    printf("%s\t%f\n",date, busyTime/((date-timePrev)*1000000))
                    #ratio+=busyTime/((date-timePrev)*1000000)
                    count++
                    timePrev=date 
                    busyTime=0
                    
                }
                    
        } #end intervalle 10 - 30 seconde
    
    
}#CORE

END {
  printf("# %s\t%f\n",date,busyTotal/((timeEndExp-(timeStartExp+1))*1000000)) 
  #printf("# %s\t%f\n",date,ratio/count)
    
}


