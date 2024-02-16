## Compute the number and the frequency of each mavLink status message
## They are not all present here, one should add any report of interest

## Used rapport==1 to get report of each second instead of the final report only

BEGIN{
    
    numberOfFrame=0
    
    pktAttitude=0
    pktHeartbeat=0
    pktAttitudeTarget=0
    pktRadioStatus=0
    pktVFRHUD=0
    pktLocalPosition=0
    pktExtendedSysState=0
    pktBatteryStatus=0
    pktDistanceSensor=0
    pktGPS=0
    pktCommandLong=0
    pktCommandAck=0
    pktItemReached=0
    pktVibration=0
    
    pktPosTargetLocalNed=0
    pktAltitude=0
    pktTimeSync=0
    pktSystemTime=0
    pktVFRHUD=0
    pktRCChannels=0
    pktTrajectoryRepresentationWaypoints=0
    
    tmpAttitude=0
    tmpHeartbeat=0
    tmpAttitudeTarget=0
    tmpRadioStatus=0
    tmpVFRHUD=0
    tmpLocalPosition=0
    tmpExtendedSysState=0
    tmpBatteryStatus=0
    tmpDistanceSensor=0
    tmpGPS=0
    tmpCommandLong=0
    tmpCommandAck=0
    tmpItemReached=0
    tmpVibration=0
    tmpVFRHUD=0
    tmpPosTargetLocalNed=0
    tmpAltitude=0
    tmpTimeSync=0
    tmpSystemTime=0
    tmpRCChannels=0
    tmpTrajectoryRepresentationWaypoints=0

    IDATTITUDE = "(30)"
    IDHEARTBEAT= "(0)"
    IDATTITUDETARGET = "(83)"
    IDRADIOSTATUS = "(109)"
    IDVFRHUD = "(74)"
    IDLOCALPOSITION ="(32)"
    IDEXTENDEDSYSSTATE ="(245)"
    IDBATTERYSTATUS ="(147)"
    IDDISTANCESENSOR ="(132)"
    IDGPS="(24)"
    IDCOMMANDLONG="(76)"
    IDCOMMANDACK="(77)"
    IDITEMREACHED="(46)"
    IDVIBRATION="(241)"
    
    IDPOSTARGETLOCALNED="(84)"
    IDALTITUDE="(141)"
    IDTIMESYNC="(111)"
    IDSYSTEMTIME="(2)"
    IDVFRHUD="(74)"
    IDRCCHANNELS="(65)"
    IDTRAJECTORYREPRESENTATIONWAYPOINTS="(332)"
    
    commandTakeOff="(22)"
    commandDisarm="(400)"
    
    first=1
    timeStep=1.0
    
    
    
}


{ ## CORE
    
    if ($1 == "Frame"){
        frameId=$2
    }
    
    if ($1 == "[Time" && $2 == "since" && $3 == "reference"){
       # datePrev=date    
        date = $7
            if (first==1){
                datePrev = $7
                first=0
            }
            
    
    
    #print "date : " date " datePrev " datePrev
        if ( rapport == 1 ){
            if ( date - datePrev >= timeStep){
                
                
                printf("Durant les dernières %f secondes (%s): \n",timeStep,date)
                printf("\t Heartbeat %d \n",tmpHeartbeat)
                printf("\t AttitudeTarget %d \n",tmpAttitudeTarget)
                printf("\t RadioStatus %d \n",tmpRadioStatus)
                printf("\t VFRHUD %d \n",tmpVFRHUD)
                printf("\t ExtendedSysState %d \n",tmpExtendedSysState)
                printf("\t BatteryStatus %d \n",tmpBatteryStatus)
                printf("\t DistanceSensor %d \n",tmpDistanceSensor)
                printf("\t GPS %d \n",tmpGPS)
                printf("\t CommandLong %d \n",tmpCommandLong)
                printf("\t CommandAck %d \n",tmpCommandAck)
                printf("\t ItemReached %d \n",tmpItemReached)  
                printf("\t Vibration %d \n",tmpVibration)  
                printf("\t VFRHUD %d \n",tmpVFRHUD)  
                printf("\t PosTargetLocalNed %d \n",tmpPosTargetLocalNed)  
                printf("\t Altitude %d \n",tmpAltitude)  
                printf("\t TimeSync %d \n",tmpTimeSync)  
                printf("\t SystemTime %d \n",tmpSystemTime)  
                printf("\t RCChannels %d \n",tmpRCChannels)  
                printf("\t TrajectoryRepresentationWaypoints %d \n",tmpTrajectoryRepresentationWaypoints)  
            
                
                datePrev=date
                
                tmpAttitude=0
                tmpHeartbeat=0
                tmpAttitudeTarget=0
                tmpRadioStatus=0
                tmpVFRHUD=0
                tmpLocalPosition=0
                tmpExtendedSysState=0
                tmpBatteryStatus=0
                tmpDistanceSensor=0
                tmpGPS=0
                tmpCommandLong=0
                tmpCommandAck=0
                tmpItemReached=0
                tmpVibration=0
                tmpVFRHUD=0
                tmpPosTargetLocalNed=0
                tmpAltitude=0
                tmpTimeSync=0
                tmpSystemTime=0
                tmpRCChannels=0
                tmpTrajectoryRepresentationWaypoints=0

            } 
        }   
    
    }
    
    if( $1 == "Message" && $2=="id:" && $4 == IDHEARTBEAT ){
            pktHeartbeat++
            tmptHeartbeat++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDATTITUDE ){
            pktAttitude++
            tmpAttitude++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDATTITUDETARGET ){
            pktAttitudeTarget++
            tmpAttitudeTarget++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDRADIOSTATUS ){
            pktRadioStatus++
            tmpRadioStatus++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDVFRHUD ){
            pktVFRHUD++
            tmpVFRHUD++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDLOCALPOSITION ){
            pktLocalPosition++
            tmpLocalPosition++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDEXTENDEDSYSSTATE ){
            pktExtendedSysState++
            tmpExtendedSysState++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDBATTERYSTATUS ){
            pktBatteryStatus++
            tmpBatteryStatus++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDDISTANCESENSOR ){
            pktDistanceSensor++
            tmpDistanceSensor++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDGPS ){
            pktGPS++
            tmpGPS++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDCOMMANDLONG ){
            pktCommandLong++
            tmpCommandLong++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDCOMMANDACK ){
            pktCommandAck++
            tmpCommandAck++
    }   
    if( $1 == "Message" && $2=="id:" && $4 == IDITEMREACHED ){
            pktItemReached++
            tmpItemReached++
    }
    if( $1 == "Message" && $2=="id:" && $4 == IDVIBRATION ){
            pktVibration++
            tmpVibration++
    }

        if( $1 == "Message" && $2=="id:" && $4 == IDVFRHUD){
            pktVFRHUD++
            tmpVFRHUD++
    }

        if( $1 == "Message" && $2=="id:" && $4 == IDPOSTARGETLOCALNED){
            pktPosTargetLocalNed++
            tmpPosTargetLocalNed++
    }

        if( $1 == "Message" && $2=="id:" && $4 == pktAltitude ){
            pktAltitude++
            tmpAltitude++
    }

        if( $1 == "Message" && $2=="id:" && $4 == IDTIMESYNC ){
            pktTimeSync++
            tmpTimeSync++
    }
        
        if( $1 == "Message" && $2=="id:" && $4 == IDSYSTEMTIME){
            pktSystemTime++
            tmpSystemTime++
    }

        if( $1 == "Message" && $2=="id:" && $4 == IDRCCHANNELS ){
            pktRCChannels++
            tmpRCChannels++
    }

        if( $1 == "Message" && $2=="id:" && $4 == IDTRAJECTORYREPRESENTATIONWAYPOINTS ){
            pktTrajectoryRepresentationWaypoints++
            tmpTrajectoryRepresentationWaypoints++
    }

    
} ## CORE



END{

    printf("Sur l'ensemble de cette trace : (%s) \n",date)
        printf("\t Heartbeat %d (%f/s)\n",pktHeartbeat,pktHeartbeat/date)
        printf("\t Attitude %d (%f/s)\n",pktAttitude,pktAttitude/date)
        printf("\t AttitudeTarget %d (%f/s)\n",pktAttitudeTarget,pktAttitude/date)
        printf("\t RadioStatus %d (%f/s)\n",pktRadioStatus,pktRadioStatus/date)
        printf("\t VFRHUD %d (%f/s)\n",pktVFRHUD,pktVFRHUD/date)
        printf("\t ExtendedSysState %d (%f/s)\n",pktExtendedSysState,pktExtendedSysState/date)
        printf("\t BatteryStatus %d (%f/s)\n",pktBatteryStatus,pktBatteryStatus/date)
        printf("\t DistanceSensor %d (%f/s)\n",pktDistanceSensor,pktDistanceSensor/date)
        printf("\t GPS %d (%f/s)\n",pktGPS,pktGPS/date)
        printf("\t CommandLong %d (%f/s)\n",pktCommandLong,pktCommandLong/date)
        printf("\t CommandAck %d (%f/s)\n",pktCommandAck,pktCommandAck/date)
        printf("\t ItemReached %d (%f/s)\n",pktItemReached,pktItemReached/date)
        printf("\t Vibration %d (%f/s)\n",pktVibration,pktVibration/date)
        
        printf("\t VFRHUD %d (%f/s)\n",pktVFRHUD,pktVFRHUD/date)  
        printf("\t PosTargetLocalNed %d (%f/s)\n",pktPosTargetLocalNed,pktPosTargetLocalNed/date)  
        printf("\t Altitude %d (%f/s)\n",pktAltitude,pktAltitude/date)  
        printf("\t TimeSync %d (%f/s)\n",pktTimeSync,pktTimeSync/date)  
        printf("\t SystemTime %d (%f/s)\n",pktSystemTime,pktSystemTime/date)  
        printf("\t RCChannels %d (%f/s)\n",pktRCChannels,pktRCChannels/date)  
        printf("\t TrajectoryRepresentationWaypoints %d (%f/s)\n",pktTrajectoryRepresentationWaypoints,pktTrajectoryRepresentationWaypoints/date)  


}
