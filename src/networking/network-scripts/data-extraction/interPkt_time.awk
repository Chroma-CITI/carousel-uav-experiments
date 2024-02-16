## Computes average inter frames time

## Has to be executed on -V versions of captures

## /!\ Take all frames arriving on NIC into account (in and out)
## Filter should be applyed on source file to select frame in or out (or both)
onner que les trames in ou out


BEGIN{
    
    timeStep=1.0
    timePrev=0.0
    
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
    
    
    if ($1 == "[Time" && $2 =="delta" && $3=="from" && $4=="previous" && $5=="displayed" && $6="frame:")  {
            # Change . by , for the be able to read the value as a float
            gsub(/\./, ",", $7)
            interpkt+=$7
            interpktTotal+=interpkt
            count++
            countTotal++
#             printf (" busyTime : %f busyTotal %f \n", busyTime/1000000,busyTotal/1000000)
    }
    
    if (date - timePrev >= timeStep){
        
        
        printf("%s\t%.10f\n",date, interpkt/count)
        ratio+=interpkt/count
        ratiocount++
        count=0
        timePrev=date 
        interpkt=0
        
    }
    
    

}#CORE

END {
    
  printf("# %s\t%.10f\n",date,ratio/ratiocount)
    
}
