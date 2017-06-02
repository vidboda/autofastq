#!/bin/bash

###########################################################################
#########							###########
#########		Autofastq				###########
######### @uthor : D Baux	david.baux<at>inserm.fr		###########
######### Date : 13/04/2016					###########
#########							###########
###########################################################################

###########################################################################
###########
########### 	Script to automate bcl2fastq utility
########### 	to convert bcl files form NextSeq
###########
###########################################################################


####	This script is meant to be croned
####	must check the runs directory, identify new runs
####	and launch bcl2fastq when a new run finishes


##############		If any option is given, print help message	##################################
VERSION=1.1
USAGE="
Program: Autofastq 
Version: ${VERSION}
Contact: Baux David <david.baux@inserm.fr>

Usage: This script is meant to be croned
	Should be executed once per minute

"


if [ $# -ne 0 ]; then
	echo "${USAGE}"
	echo "Error Message : Arguments provided"
	echo ""
	exit 1
fi


###############		Get options from conf file			##################################

CONFIG_FILE='/home/adminngs/autofastq/autofastq.conf'

#we check params against regexp

UNKNOWN=$(cat  ${CONFIG_FILE} | grep -Evi "^(#.*|[A-Z0-9_]*=[a-z0-9_ \.\/\$\{\}]*)$")
if [ -n "${UNKNOWN}" ]; then
	echo "Error in config file. Not allowed lines:"
	echo ${UNKNOWN}
	exit 1
fi

source ${CONFIG_FILE}

###############		1st check whether another instance of the script is running	##################

RESULT=$(ps x | grep -v grep | grep -c ${SERVICE})
#echo `ps x | grep -v grep |grep ${SERVICE} `
#echo "Result: ${RESULT}"

if [ "${RESULT}" -gt 3 ]; then
	exit 0
fi 
#echo "Passed"

###############		Get run info file				 ##################################

# the file contains the run id and a code
# 0 => not converted => to do - used to reconvert a run in case ex of error
# 1 => conversion is running -in case the security above does not work
# 2 => conversion done - ignore directory
# the file is stored in an array and modified by the script

declare -A RUN_ARRAY #init array
while read LINE
do
	if echo ${LINE} | grep -E -v '^(#|$)' &>/dev/null; then
		if echo ${LINE} | grep -F '=' &>/dev/null; then
			RUN_ID=$(echo "${LINE}" | cut -d '=' -f 1)
			RUN_ARRAY[${RUN_ID}]=$(echo "${LINE}" | cut -d '=' -f 2-)
		fi
	fi
done < ${RUNS_FILE}

#for RUN_ID in ${!RUN_ARRAY[*]}
#do
#	echo "${RUN_ID}=${RUN_ARRAY[${RUN_ID}]}"
#done
#exit
###############		Now we'll have a look at the content of the directory ###############################


#http://moinne.com/blog/ronald/bash/list-directory-names-in-bash-shell
#--time-style is used here to ensure awk $8 will return the right thing (dir name)
RUNS=$(ls -l --time-style="long-iso" ${RUNS_DIR} | egrep '^d' | awk '{print $8}')
#command above does not work on OSX

for RUN in ${RUNS}
do
	if [ -z "${RUN_ARRAY[${RUN}]}" ] || [ "${RUN_ARRAY[${RUN}]}" -eq 0 ];then		
		###get run prefix for samplesheet management 160818 david
		PREFIX=$(echo ${RUN} | cut -d '_' -f 1)
		###
		#now we must look for the RTAComplete.txt file
		if [ -e "${RUNS_DIR}${RUN}/RTAComplete.txt" ] && [ ! -e "${RUNS_DIR}converted/${RUN}/RTAComplete.txt" ]; then
			#if [ -e "${RUNS_DIR}${RUN}/SampleSheet.csv" ];then
			###check for samplesheet presence 160818 david
			if [ -e "${RUNS_DIR}samplesheets/${PREFIX}.csv" ];then
			###
				###david 19/08/16 copy run folder in  'conversion_tmp' subfolder
				echo "$(date) copying ${RUN} in conversion_tmp/ folder"
				rsync -avq --exclude='Data' "${RUNS_DIR}${RUN}" "${RUNS_DIR}conversion_tmp/"
				echo "$(date) launching ${BCL2FASTQ} on ${RUN}"						
				#pass ${RUN} to running
				if [ -z "${RUN_ARRAY[${RUN}]}" ];then
					echo ${RUN}=1 >> ${RUNS_FILE}
					RUN_ARRAY[${RUN}]=1
				elif [ "${RUN_ARRAY[${RUN}]}" -eq 0 ];then
					#Change value on array and file to running
					sed -i -e "s/${RUN}=0/${RUN}=1/g" "${RUNS_FILE}"
					RUN_ARRAY[${RUN}]=1
				fi
				#launch bcl2fastq
				#comment to test blank
				mkdir -p "${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq"				
				touch "${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq/bcl2fastq.log"
				mkdir -p "${RUNS_DIR}conversion_tmp/${RUN}/FastQs"
				####change samplesheet management 160818 david
				nohup ${BCL2FASTQ} -R ${RUNS_DIR}${RUN} --stats-dir ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq --reports-dir ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq --barcode-mismatches 0 --no-lane-splitting --sample-sheet ${RUNS_DIR}samplesheets/${PREFIX}.csv -o ${RUNS_DIR}conversion_tmp/${RUN}/FastQs > ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq/bcl2fastq.log 2>&1
				####	
				#-r -d -p -w: default is ok on VM
				#--fastq-compression-level : default tested with 9  increased treatment 100% time for <10% space gained
				#check exit status - if ne 0 then put run in error (status 1)
				#echo "Exit Status $?"
				if [ "$?" -eq 0 ];then
					##Change value on array and file to done		
					sed -i -e "s/${RUN}=1/${RUN}=2/g" "${RUNS_FILE}"
					RUN_ARRAY[${RUN}]=2
					#move run in 'converted' folder
					#mv "${RUNS_DIR}conversion_tmp/${RUN}" "${RUNS_DIR}converted/${RUN}" && echo "$(date) ${RUN} moved to ${RUNS_DIR}converted/${RUN}"
					#echo "MV COMMAND (DEBUGGING): mv \"${RUNS_DIR}conversion_tmp/${RUN}\" \"${RUNS_DIR}converted/${RUN}\""
					#170131 david changed mv with cp && rm
					cp -R "${RUNS_DIR}conversion_tmp/${RUN}" "${RUNS_DIR}converted/${RUN}"
					#echo "cp Exit status $?"
					if [ "$?" -eq 0 ];then
						rm -rf "${RUNS_DIR}conversion_tmp/${RUN}"
						echo "$(date) ${RUN} moved to ${RUNS_DIR}converted/${RUN}"
					fi
					#end change david
					if [ -e "${RUNS_DIR}${RUN}/nosamplesheet.txt" ];then
						rm "${RUNS_DIR}${RUN}/nosamplesheet.txt"
					fi
					echo "$(date) ${RUN} converted"
				else
					echo "$(date) ERROR in bcl2fastq execution: relaunching with  --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions"
					nohup ${BCL2FASTQ} -R ${RUNS_DIR}${RUN} --stats-dir ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq --reports-dir ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq --barcode-mismatches 0 --no-lane-splitting --sample-sheet ${RUNS_DIR}samplesheets/${PREFIX}.csv --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions -o ${RUNS_DIR}conversion_tmp/${RUN}/FastQs > ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq/bcl2fastq.log 2>&1
					if [ "$?" -eq 0 ];then
						##Change value on array and file to done		
						sed -i -e "s/${RUN}=1/${RUN}=2/g" "${RUNS_FILE}"
						RUN_ARRAY[${RUN}]=2
						#move run in 'converted' folder
						#mv "${RUNS_DIR}conversion_tmp/${RUN}" "${RUNS_DIR}converted/${RUN}" && echo "$(date) ${RUN} moved to ${RUNS_DIR}converted/${RUN}"
						#170131	david changed mv with cp && rm
                                        	cp -R "${RUNS_DIR}conversion_tmp/${RUN}" "${RUNS_DIR}converted/${RUN}"
                                        	if [ "$?" -eq 0 ];then
                                                	rm -rf "${RUNS_DIR}conversion_tmp/${RUN}"
                                                	echo "$(date) ${RUN} moved to ${RUNS_DIR}converted/${RUN}"
                                        	fi
                                        	#end change david
						if [ -e "${RUNS_DIR}${RUN}/nosamplesheet.txt" ];then
							rm "${RUNS_DIR}${RUN}/nosamplesheet.txt"
						fi
						echo "$(date) ${RUN} converted with --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions"
					else
						echo "$(date) ERROR in bcl2fastq execution: check log file ${RUNS_DIR}${RUN}/bcl2fastq/bcl2fastq.log."
					fi
				fi
			else
				if [ ! -e "${RUNS_DIR}${RUN}/nosamplesheet.txt" ];then
					echo "$(date) No Sample sheet for run ${RUN} or change name to '${PREFIX}.csv' in folder NEXTSEQ/runs/samplesheets"
					touch "${RUNS_DIR}${RUN}/nosamplesheet.txt"
				fi
			fi
		fi
	fi
done

exit 0