#!/bin/bash 

helpstring="Usage: doQC7_complete.sh -c [DetName]
	Can be used to doQC7 completely from scratch or for retest purposes  
	Options:
		-s uTCA shelf number
		-a AMC slot number inside uTCA shelf
		-n oh number
		-o ohMask to use
		-c chamber name, without '/' characters, e.g. 'GE11-X-S-CERN-0007'
		-g GEM detector type (i.e. 'long' or 'short')
		-d good dac scan date
		-u upto which step the test should be done (dt (only doQC7 or testconnectivity), sb (sbit), sc (scurve) )
Authors: Nimantha Perera & Kailasapathy Balashangar"

AMCSLOT="5"
CHAMBER_NAME=""
DETTYPE="short"
GEMTYPE="ge11"
OHMASK="0x10"
SHELF="2"

OPTIND=1
while getopts "s:a:n:o:c:g:d:u:hd" opts
do
    case $opts in
        s)
            SHELF="$OPTARG";;
        a)
            AMCSLOT="$OPTARG";;
        n)
            OH_NO="$OPTARG";;
        o)
            OHMASK="$OPTARG";;
        c)
            CHAMBER_NAME="$OPTARG";;
        g)
            DETTYPE="$OPTARG";;    
        d)
            DACSD="$OPTARG";;
		u)
			UPTO="$OPTARG";;
        h)
            echo >&2 "${helpstring}"
            kill -INT $$;;
        \?)
            echo >&2 "${helpstring}"
            kill -INT $$;;
        [?])
            echo >&2 "${helpstring}"
            kill -INT $$;;
    esac
done
unset OPTIND


#Getting confirmation to proceed.
read -p "Remember you should supply all the variables except for DAC scandate (only needed if you are running testConnectivity for first time on this CTP7) and upto for this to work properly. Are you sure you want to continue (y/n)?" CONT
if [ "$CONT" = "y" ]
then
	if [ -z "${DACSD}" ]
    then
        echo -e "\e[31mThe DAC scan values will not be loaded hope you have already done it (Not needed for doQC7 or if you are running testConnectivity consecutively for the second time on the same stand)\e[39m"
    fi

	echo ========================================================================================================
    
    read -p "Do you want to do the whole doQC7 y/n ? (if no testConnectivity skipping scurve & DAC scan will take place)" YN
    if [ "$YN" = "y" ]
    then
        # Running doQC7 and analysing the scurve
        rm /data/bigdisk/GEM-Data-Taking/GE11_QC8/${CHAMBER_NAME}/calFile_ADC0_${CHAMBER_NAME}.txt
        rm /data/bigdisk/GEM-Data-Taking/GE11_QC8/${CHAMBER_NAME}/calFile_calDac_${CHAMBER_NAME}.txt
        time_check=$(date +%S);     if [ $time_check -gt 58 ];     then         sleep 2;         fi;
        time_con=$(date +%Y.%m.%d.%H.%M)

        SECONDS=0
        doQC7.sh -s ${SHELF} -a ${AMCSLOT} -o ${OHMASK} -c ${CHAMBER_NAME}
        duration=$SECONDS; if [ $duration -lt 900 ];   then    echo -e "\e[31mConnectivity probably failed\e[39m";    exit 0; fi;
           
        anaUltraScurve.py /data/bigdisk/GEM-Data-Taking/GE11_QC8//${CHAMBER_NAME}/scurve/${time_con}/SCurveData.root -c ${DETTYPE} --calFile=/data/bigdisk/GEM-Data-Taking/GE11_QC8/${CHAMBER_NAME}/calFile_calDac_${CHAMBER_NAME}.txt &
		if [ "${UPTO}" = "dt" ];    then    exit 0; fi;


    elif [ "$YN" = "n" ] 
    then
        #Running testConnectivity
        time_check=$(date +%S);     if [ $time_check -gt 58 ];     then         sleep 2;         fi;
        time_con=$(date +%Y.%m.%d.%H.%M)
        testConnectivity.py ${SHELF} ${AMCSLOT} ${OHMASK} -c ${CHAMBER_NAME} --detType=${DETTYPE} --gemType=ge11 --skipDACScan --skipScurve 2>&1 | tee /data/bigdisk/GEM-Data-Taking/GE11_QC8/${CHAMBER_NAME}/connectivityLog_${CHAMBER_NAME}_${time_con}.txt
        if [ "${UPTO}" = "dt" ];    then    exit 0; fi;
    else
        echo -e "\e[31mNo good input given. Exiting....\e[39m"
        exit 0 
    fi
    #Updating IREF values
    getCalInfoFromDB.py ${SHELF} ${AMCSLOT} ${OH_NO} --write2CTP7
    if ! [ -z "${DACSD}" ]
    then
        #Updating the DAC values
        updateVFAT3ConfFiles.py ${SHELF} ${AMCSLOT} ${OH_NO} --scandate ${DACSD}
    fi
    
    #Configuring the chamber
    confChamber.py -g ${OH_NO} --shelf ${SHELF} -s ${AMCSLOT} --run

    #Taking and analyzing the sbit rate
    time_check=$(date +%S);     if [ $time_check -gt 58 ];     then         sleep 2;         fi;
	scandateSBIT=$(date +%Y.%m.%d.%H.%M)
	run_scans.py sbitThresh ${SHELF} ${AMCSLOT} ${OHMASK}
	ana_scans.py sbitThresh -i /data/bigdisk/GEM-Data-Taking/GE11_QC8//sbitRate/channelOR/$scandateSBIT/SBitRateData.root --chamberConfig -m 100
	if [ "${UPTO}" = "sb" ];    then    exit 0; fi;

    #Configuring the chamber with the VFAT config from the sbit taken
	confChamber.py --shelf ${SHELF} -s ${AMCSLOT} -g ${OH_NO} --run --vfatConfig /data/bigdisk/GEM-Data-Taking/GE11_QC8/${CHAMBER_NAME}/sbitRate/channelOR//${scandateSBIT}/vfatConfig.txt

    #Taking and analyzing the scurve
    time_check=$(date +%S);     if [ $time_check -gt 58 ];     then         sleep 2;         fi;
	scandateSCurve2=$(date +%Y.%m.%d.%H.%M)
    #scandateSCurve2=2019.10.09.17.47
	run_scans.py scurve ${SHELF} ${AMCSLOT} ${OHMASK}
	
	anaUltraScurve.py /data/bigdisk/GEM-Data-Taking/GE11_QC8/${CHAMBER_NAME}/scurve/${scandateSCurve2}/SCurveData.root ${DETTYPE} -c --calFile=/data/bigdisk/GEM-Data-Taking/GE11_QC8/${CHAMBER_NAME}/calFile_calDac_${CHAMBER_NAME}.txt &
    pid=$!
   
    # && mv /data/bigdisk/GEM-Data-Taking/GE11_QC8/GE11-X-L-GHENT-0012/scurve/${scandateSCurve2}/SCurveData/Summary.png /data/bigdisk/GEM-Data-Taking/GE11_QC8/GE11-X-L-GHENT-0012/scurve/${scandateSCurve2}/SCurveData/Summary2.png

    #Taking and analyzing the threshold scan data
    time_check=$(date +%S);     if [ $time_check -gt 58 ];     then         sleep 2;         fi;
    scandateTHR=$(date +%Y.%m.%d.%H.%M)
	run_scans.py thrDac ${SHELF} ${AMCSLOT} ${OHMASK}
	ana_scans.py thrDac -s ${scandateTHR} --chamberConfig --medium -c

	echo $(tput setaf 2)============================================================================================$(tput sgr 0)
	echo Connectivity - ${time_con}    SBit -  ${scandateSBIT} Scurve-100Hz - ${scandateSCurve2} Threshold - ${scandateTHR}
	echo $(tput setaf 2)============================================================================================$(tput sgr 0)
    if ps | grep "$pid[^[]" >/dev/null        
	then
		echo $(tput setaf 3)Scurve analysis is still going on wait for sometime$(tput sgr 0); wait $pid; echo $(tput setaf 2)EVERYTHING IS COMPLETE NOW $(tput sgr 0) 
	else
		echo $(tput setaf 2)ALL COMPLETE $(tput sgr 0)
	fi
    #Preparing the elog
	if [ "$YN" = "y" ]
	then
		sed "s/{CHAMBER_NAME}/${CHAMBER_NAME}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog.txt > /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
	elif [ "$YN" = "n" ]
	then
		if ! [ -z "${DACSD}" ]
		then
			sed "s/{CHAMBER_NAME}/${CHAMBER_NAME}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog_connectivity.txt > /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
			sed -i "s/{DACSD}/${DACSD}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
		else
			sed "s/{CHAMBER_NAME}/${CHAMBER_NAME}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog_connectivity_woDACSD.txt > /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
		fi
	fi
	sed -i "s/{SHELF}/${SHELF}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    sed -i "s/{AMCSLOT}/${AMCSLOT}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    sed -i "s/{OHMASK}/${OHMASK}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    sed -i "s/{time_con}/${time_con}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    sed -i "s/{DETTYPE}/${DETTYPE}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    sed -i "s/{scandateSBIT}/${scandateSBIT}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    sed -i "s/{OH_NO}/${OH_NO}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    sed -i "s/{scandateSCurve2}/${scandateSCurve2}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    sed -i "s/{scandateTHR}/${scandateTHR}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
#    sed "s/{DACSD}/${DACSD}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
#    sed "s/{}/${}/g" /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog.txt > /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
    echo $(tput setaf 2)The elog can be found at /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt$(tput sgr 0)
    exit 0
    #xclip -i -selection c /data/bigdisk/GEM-Data-Taking/GE11_QC8/Nimantha/qc7_elog${SHELF}${AMCSLOT}${OH_NO}.txt
else
    echo $(tput setaf 3)Process have been terminated$(tput sgr 0) 
fi
exit 0
