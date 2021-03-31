# autofastq
script to automate Illumina bcl2fastq utility

## Goals
Illumina runs generates bcl files that need to be converted to fastq before secondary analysis. This script automates and monitors the conversion.

## What is it
This is a simple shell script. It reads a very simple conf file mainly to get path from your environment.
It also uses a simple text file (runs.txt) as database to keep track of the runs and possibly requeue a conversion.
The script should be croned at your convenience.

## How it works
The script just checks the run directory and looks for new runs that possibly can be terminated (presence of the RTAComplete.txt file).

## Installation
* First you need to install [bcl2fastq](https://support.illumina.com/downloads.html).

Clone the repository, then complete the autofastq.conf.empty file with the following paths and rename it to autofastq.conf:

BASE_DIR=/full/path/to/your/illumina/folder

RUNS_DIR=/actual/path/to/the/runs (from $BASE_DIR)

TRIGGER_FILE=name of file to be searched to trigger bcl2fatsq in RUNS_DIR, e.g. RTAComplete.txt or CopyComplete.txt

SSHEET_DIR_NAME=samplesheets(samplesheets folder basename inside $RUNS_DIR)

SERVICE=script_name(autofastq.sh)

RUNS_FILE=/full/path/to/the/file/runs.txt

BCL2FASTQ=/path/to/the/executable/bcl2fastq

DOS2UNIX=/patho/to/dos2unix

RSYNC=/path/to/rsync

MD5=true

MD5EXE=/path/to/md5(sum)



* You should have a ${RUNS_DIR}/samplesheets directory with read permissions.

In ${RUNS_DIR}/samplesheets the script expects to find sample sheets which are Illumina regular sample sheets, however the script will look for a sample sheet with the following name convention:

YYMMDD.csv

which corresponds to the 6 first characters of you run folder (and which is actually the date).

* Rename runs.txt.empty to runs.txt

* change line 47 of the autofastq.sh script to point to your autofastq.conf file:

CONFIG_FILE='/path/to/autofastq/autofastq.conf'

* Cron autofastq, ex, launch every minute:

\* \* \* \* \* /path/to/autofastq.sh >> /path/to/run/dir/autofastq.log 2>&1

You should be done!

## Monitoring
Check /path/to/run/dir/autofastq.log for troubleshootings.


