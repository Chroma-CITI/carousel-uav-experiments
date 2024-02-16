## Compute loss rate at layer 2 based on MAC sequence numbers
## Usable only on monitor captured files

## Has to be executed on -V versions of captures

## /!\ tshark filter has to be applied carefully
## Results can easly becomes absurd

## /!\ Two strong hypothesis :
## - Monitor is placed closed to control and perturbation computers
## - Assuming monitor do not "miss" any frame 

BEGIN {
    
    timeStep=1.0
    timePrev=0.0
    
}


{ # CORE
    
    if ($1 == "[Time" && $2 == "since" && $3 == "reference"){
    
        date = $7
            if (first==1){
                datePrev = $7
                first=0
            }
    }
    
    
    
    if ($4=="Retry:" && $5=="Frame" && $6=="is" && $7=="not"){
        framecount++
        framecount_step++
        
    }
    else if ($4=="Retry:" && $5=="Frame" && $6=="is" && $7=="being"){
        framecount++
        framecount_step++
        retrycount++
        retrycount_step++
    }
    
    
    if (date - timePrev >= timeStep){
        printf("%s\t%f\n",date, retrycount_step/framecount_step)
        timePrev=date 
        framecount_step=0
        retrycount_step=0
        
    }
    
    
    
    
} # CORE


END{
    
    printf("#%s\t%f\t%ld\t%ld\n",date,retrycount/framecount,retrycount,framecount)
    
}
