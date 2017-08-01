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
* First you need to install [bcl2fastq](https://support.illumina.com/downloads/bcl2fastq-conversion-software-v2-18.html).

Clone the repository, then complete the autofastq.conf.empty file with the following paths and rename it to autofastq.conf:

BASE_DIR=full/path/to/your/illumina/folder

RUNS_DIR=actual/partial/path/to/the/runs (from ${BASE_DIR})

SERVICE=name_of_script.sh

RUNS_FILE=full/path/to/the/file/runs.txt

BCL2FASTQ=path/to/the/executable/bcl2fastq

* You should have a directory ${RUNS_DIR}/converted and write permissions on ${RUNS_DIR}.

* You should also have a ${RUNS_DIR}/conversion_tmp with write permissions and a ${RUNS_DIR}/samplesheets with read permissions.

In ${RUNS_DIR}/samplesheets the script expects to find sample sheets which are Illumina regular sample sheets, however the script will look for a sample sheet with the following name convention:

YYMMDD.csv

which corresponds to the 6 first characters of you run folder (and which is actually the date).

* Rename runs.txt.empty to runs.txt

* Cron autofastq, ex, launch every minute:

\* \* \* \* \* /path/to/autofastq.sh >> /path/to/run/dir/autofastq.log 2>&1

You should be done!

## Monitoring
Check /path/to/run/dir/autofastq.log for troubleshootings.


