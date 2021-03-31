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
VERSION=1.2
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
	echo "$(date) ERROR: in config file. Not allowed lines:"
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

###############		Test if ${RUNS_FILE} file is writable		##################################

if [ ! -w ${RUNS_FILE} ];then
	echo "$(date) ERROR: ${RUNS_FILE} not writable!!!"
	exit 1
fi


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
#TARGET='converted'
#command above does not work on OSX

for RUN in ${RUNS}
do
	if [ -z "${RUN_ARRAY[${RUN}]}" ] || [ "${RUN_ARRAY[${RUN}]}" -eq 0 ];then		
		###get run prefix for samplesheet management 160818 david
		PREFIX=$(echo ${RUN} | cut -d '_' -f 1)
		###
		#now we must look for the TRIGGER_FILE, e.g. CopyComplete.txt or RTAComplete file
		if [ -e "${RUNS_DIR}${RUN}/${TRIGGER_FILE}" ];then
			###check for samplesheet presence 160818 david
			if [ -e "${RUNS_DIR}${SSHEET_DIR_NAME}/${PREFIX}.csv" ];then
			###
				#david 18/10/2018 dos2unix added
				"${DOS2UNIX}" "${RUNS_DIR}${SSHEET_DIR_NAME}/${PREFIX}.csv"
				###david 19/08/16 copy run folder in  'conversion_tmp' subfolder
				#echo "$(date) INFO copying ${RUN} in ${TARGET} folder"
				#"${RSYNC}" -aq --exclude='Data' "${RUNS_DIR}${RUN}" "${RUNS_DIR}${TARGET}/"
				echo "$(date) INFO launching ${BCL2FASTQ} on ${RUN}"						
				#pass ${RUN} to running
				if [ -z "${RUN_ARRAY[${RUN}]}" ];then
					echo ${RUN}=1 >> ${RUNS_FILE}
					RUN_ARRAY[${RUN}]=1
				elif [ "${RUN_ARRAY[${RUN}]}" -eq 0 ];then
					#Change value on array and file to running
					sed -i -e "s/${RUN}=0/${RUN}=1/g" "${RUNS_FILE}"
					RUN_ARRAY[${RUN}]=1
				fi
				#old conversion_tmp
				#mkdir -p "${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq"				
				#touch "${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq/bcl2fastq.log"
				#rsync -aq "${RUNS_DIR}samplesheets/${PREFIX}.csv" "${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq/SampleSheet.csv"
				#mkdir -p "${RUNS_DIR}conversion_tmp/${RUN}/FastQs"
				####change samplesheet management 160818 david
				#nohup ${BCL2FASTQ} -R ${RUNS_DIR}${RUN} --stats-dir ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq --reports-dir ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq --barcode-mismatches 0 --no-lane-splitting --sample-sheet ${RUNS_DIR}samplesheets/${PREFIX}.csv -o ${RUNS_DIR}conversion_tmp/${RUN}/FastQs > ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq/bcl2fastq.log 2>&1
				####
				mkdir -p "${RUNS_DIR}${RUN}/bcl2fastq"				
				touch "${RUNS_DIR}${RUN}/bcl2fastq/bcl2fastq.log"
				"${RSYNC}" -aq "${RUNS_DIR}${SSHEET_DIR_NAME}/${PREFIX}.csv" "${RUNS_DIR}${RUN}/bcl2fastq/SampleSheet.csv"
				mkdir -p "${RUNS_DIR}${RUN}/FastQs"
				####change samplesheet management 160818 david
				"${BCL2FASTQ}" -R "${RUNS_DIR}${RUN}" --stats-dir "${RUNS_DIR}${RUN}/bcl2fastq" --reports-dir "${RUNS_DIR}${RUN}/bcl2fastq" --barcode-mismatches 0 --no-lane-splitting --sample-sheet "${RUNS_DIR}${SSHEET_DIR_NAME}/${PREFIX}.csv" -o "${RUNS_DIR}${RUN}/FastQs" > "${RUNS_DIR}${RUN}/bcl2fastq/bcl2fastq.log" 2>&1
				#mkdir -p "${RUNS_DIR}${TARGET}/${RUN}/bcl2fastq"				
				#touch "${RUNS_DIR}i${TARGET}/${RUN}/bcl2fastq/bcl2fastq.log"
				#"${RSYNC}" -aq "${RUNS_DIR}${SSHEET_FOLDER}/${PREFIX}.csv" "${RUNS_DIR}${TARGET}/${RUN}/bcl2fastq/SampleSheet.csv"
				#mkdir -p "${RUNS_DIR}${TARGET}/${RUN}/FastQs"
				####change samplesheet management 160818 david
				#"${BCL2FASTQ}" -R "${RUNS_DIR}${RUN}" --stats-dir "${RUNS_DIR}${TARGET}/${RUN}/bcl2fastq" --reports-dir "${RUNS_DIR}${TARGET}/${RUN}/bcl2fastq" --barcode-mismatches 0 --no-lane-splitting --sample-sheet "${RUNS_DIR}${SSHEET_FOLDER}/${PREFIX}.csv" -o "${RUNS_DIR}${TARGET}/${RUN}/FastQs" > "${RUNS_DIR}${TARGET}/${RUN}/bcl2fastq/bcl2fastq.log" 2>&1
				#-r -d -p -w: default is ok on VM
				#--fastq-compression-level : default tested with 9  increased treatment 100% time for <10% space gained
				#check exit status - if ne 0 then put run in error (status 1)
				#echo "Exit Status $?"
				if [ "$?" -eq 0 ];then
					##Change value on array and file to done		
					sed -i -e "s/${RUN}=1/${RUN}=2/g" "${RUNS_FILE}"
					RUN_ARRAY[${RUN}]=2
					#run md5 check sum on fastqs
					if [ "${MD5}" == true ];then
						"${MD5EXE}" ${RUNS_DIR}${RUN}/FastQs/*.fastq.gz >"${RUNS_DIR}${RUN}/FastQs/md5.txt" 2>&1
					fi
					#move run in 'converted' folder
					#mv "${RUNS_DIR}conversion_tmp/${RUN}" "${RUNS_DIR}converted/${RUN}" && echo "$(date) ${RUN} moved to ${RUNS_DIR}converted/${RUN}"
					#echo "MV COMMAND (DEBUGGING): mv \"${RUNS_DIR}conversion_tmp/${RUN}\" \"${RUNS_DIR}converted/${RUN}\""
										
#170131 david changed mv with cp && rm
					#rsync -aq "${RUNS_DIR}conversion_tmp/${RUN}" "${RUNS_DIR}converted/"
					#echo "rsync Exit status $?"
					#if [ "$?" -eq 0 ];then
						#rm -rf "${RUNS_DIR}conversion_tmp/${RUN}"
						#echo "$(date) ${RUN} moved to ${RUNS_DIR}converted/${RUN}"
					#fi
					#end change david
					if [ -e "${RUNS_DIR}${RUN}/nosamplesheet.txt" ];then
						rm "${RUNS_DIR}${RUN}/nosamplesheet.txt"
					fi
					#touch "${RUNS_DIR}${RUN}/FASTQ_complete.txt"
					"${BCL2FASTQ}" --version > "${RUNS_DIR}${RUN}/FASTQ_complete.txt" 2>&1
					echo "$(date) INFO ${RUN} FASTQ conversion terminated"
				else
					echo "$(date) ERROR in bcl2fastq execution: relaunching with  --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions"
					#nohup ${BCL2FASTQ} -R ${RUNS_DIR}${RUN} --stats-dir ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq --reports-dir ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq --barcode-mismatches 0 --no-lane-splitting --sample-sheet ${RUNS_DIR}samplesheets/${PREFIX}.csv --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions -o ${RUNS_DIR}conversion_tmp/${RUN}/FastQs > ${RUNS_DIR}conversion_tmp/${RUN}/bcl2fastq/bcl2fastq.log 2>&1
					"${BCL2FASTQ}" -R "${RUNS_DIR}${RUN}" --stats-dir "${RUNS_DIR}${RUN}/bcl2fastq" --reports-dir "${RUNS_DIR}${RUN}/bcl2fastq" --barcode-mismatches 0 --no-lane-splitting --sample-sheet "${RUNS_DIR}${SSHEET_DIR_NAME}/${PREFIX}.csv" --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions -o "${RUNS_DIR}${RUN}/FastQs" >> "${RUNS_DIR}${RUN}/bcl2fastq/bcl2fastq.log" 2>&1
					if [ "$?" -eq 0 ];then
						##Change value on array and file to done		
						sed -i -e "s/${RUN}=1/${RUN}=2/g" "${RUNS_FILE}"
						RUN_ARRAY[${RUN}]=2
						if [ "${MD5}" == true ];then
							 "${MD5EXE}" ${RUNS_DIR}${RUN}/FastQs/*.fastq.gz >"${RUNS_DIR}${RUN}/FastQs/md5.txt" 2>&1
						fi
						#move run in 'converted' folder
						#mv "${RUNS_DIR}conversion_tmp/${RUN}" "${RUNS_DIR}converted/${RUN}" && echo "$(date) ${RUN} moved to ${RUNS_DIR}converted/${RUN}"
						#170131	david changed mv with cp && rm
                                        	#rsync -aq "${RUNS_DIR}conversion_tmp/${RUN}" "${RUNS_DIR}converted/"
                                        	#if [ "$?" -eq 0 ];then
                                                #	rm -rf "${RUNS_DIR}conversion_tmp/${RUN}"
                                                #	echo "$(date) ${RUN} moved to ${RUNS_DIR}converted/${RUN}"
                                        	#fi
                                        	#end change david
						if [ -e "${RUNS_DIR}${RUN}/nosamplesheet.txt" ];then
							rm "${RUNS_DIR}${RUN}/nosamplesheet.txt"
						fi
						#touch "${RUNS_DIR}${RUN}/FASTQ_complete.txt"
						"${BCL2FASTQ}" --version > "${RUNS_DIR}${RUN}/FASTQ_complete.txt" 2>&1	
						echo "$(date) INFO ${RUN} converted with --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions"
					else
						echo "$(date) ERROR in bcl2fastq execution: check log file ${RUNS_DIR}${RUN}/bcl2fastq/bcl2fastq.log."
					fi
				fi
			else
				if [ ! -e "${RUNS_DIR}${RUN}/nosamplesheet.txt" ];then
					echo "$(date) ERROR No Sample sheet for run ${RUN} or change name to '${PREFIX}.csv' in folder NEXTSEQ/runs/${SSHEET_FOLDER}"
					touch "${RUNS_DIR}${RUN}/nosamplesheet.txt"
				fi
			fi
		fi
	fi
done

exit 0
