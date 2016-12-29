#!/bin/bash
#
# This is a script designed to do all the things I do when I normally go into a monitoring alert blind.
# Basically its designed to do my job for me.
# 
# steven.bennett@rackspace.com
##################################################
#
# This script is desinged to carry out the following tasks and prepare a report:
#
# 1) Determine if any users are logged in
# 2) Check for Disk Space <90%
# 3) Determine if Load Average is nominal
# 4) Check for Apache Performance
# 5) Check for MySQL Performance
# 6) Malcious Traffic Check
# 7) Check awaiting messages in Mailq
# 8) Discovery of Environment
# 9) Report and Recommendations
#
# Usage:
# curl -k https://hoshisato.com/tools/code/domywork.sh | bash  ***NOT LIVE YET***
#
##################################################
#
# VARIABLES
WEBSERVICE=$(command -v httpd)
PSAUX=$(ps aux | sort -rk 3,3 | head -n 6 | awk '{print $3,$11}')  
SERVER=$(hostname)
 
# (1) Logged in Users
WHO=$(w | awk '{print $1}' | grep -v -e '^$' |  grep -A 10 "USER" | grep -v USER | uniq)

# (2) Disk Space Report
DISKSPACE=$(
# Disk space code modified and taken from:
# 2016 - ze.miguel.maria@gmail.com
# https://github.com/zemigpt/linux-disk-space-info
# -- auxiliary function
# CalcCols calculates the bars needed to display the selected size.
# Arguments: Size, Char, Color
function CalcCols {
	local value=$1
	local char=$2
	local color=$3
	
	#change color
	lineInfo=$lineInfo$color
	
	COUNTER=0
	while [ "$COUNTER" -lt "$value" ]; do
	  lineInfo=$lineInfo$char
	  let COUNTER=COUNTER+1 
	done
}  

# variables configuration
backupFolder="/var/lib/mysqlbackup/"
wwwFolder="/var/www/"
mntFolder="/mnt/"
cols=40 #columns of the graphic

# chars for the graphic
FilledChar='\xB1'
FreeChar='~'

# get data from file system
diskTotal=$(df / | sed -n '2p' | awk '{print $2}')
diskFree=$(df / | sed -n '2p' | awk '{print $4}')
backupSize=$(du -s $backupFolder | awk '{print $1}')
wwwSize=$(du -s $wwwFolder | awk '{print $1}')
mntSize=$(du -s $mntFolder | awk '{print $1}')
otherSize=$(($diskTotal-$diskFree-$backupSize-$wwwSize))
percentFree=$(($diskFree*100/$diskTotal))

# Calculations
wwwSizeCols=$(($wwwSize*$cols/$diskTotal)) 
wwwSizeHuman=$(awk "BEGIN {printf \"%.2f\n\", $wwwSize/1024/1024}")

backupSizeCols=$(($backupSize*$cols/$diskTotal)) 
backupSizeHuman=$(awk "BEGIN {printf \"%.2f\n\", $backupSize/1024/1024}")

mntSizeCols=$(($mntSize*$cols/$diskTotal)) 
mntSizeHuman=$(awk "BEGIN {printf \"%.2f\n\", $mntSize/1024/1024}")

otherSizeCols=$(($otherSize*$cols/$diskTotal))
otherSizeHuman=$(awk "BEGIN {printf \"%.2f\n\", $otherSize/1024/1024}")

freeSizeCols=$(($diskFree*$cols/$diskTotal))
freeSizeHuman=$(awk "BEGIN {printf \"%.2f\n\", $diskFree/1024/1024}")

#create the graphic
# initialize the var
lineInfo=""

# Calculate OS+Programs and change color to Blue
CalcCols $otherSizeCols $FilledChar 

# Calculate backup size and change color to Orange
CalcCols $backupSizeCols $FilledChar 

# Calculate WWW size and change color to Pink
CalcCols $wwwSizeCols $FilledChar 

# Calculate mnt size and change color to Pink
CalcCols $mntSizeCols $FilledChar

# Calculate free size and change color to Green
CalcCols $freeSizeCols $FreeChar 

# resets color
lineInfo=$lineInfo$NC
#

echo -e "+ Disk [$lineInfo]"
echo -e "+ OS+Programs ("$otherSizeHuman" GB)"
echo -e "+ Application files ("$wwwSizeHuman" GB) /var/www/"
echo -e "+ MySQL Backups ("$backupSizeHuman" GB) /var/lib/mysqlbackup/" 
echo -e "+ Mount Size ("$mntSizeHuman" GB) /mnt/" 
echo -e "+ Free space on / ("$freeSizeHuman" GB)" 

# If low free space warn user
if [ "$percentFree" -lt "10" ]; then
  echo "Free disk space less than 10%!"
fi
)


# (3) Load Average Report
LOAD=$(w | grep load | awk '{print $12}' | cut -f1 -d".")
PCOUNT=$(grep processor /proc/cpuinfo | wc -l)
LOADNOMINAL=$(
if (( $LOAD > $PCOUNT ));
then 
   echo "DANGEROUS";
   echo " ";
   echo " Here are the top 5 CPU intensive processes:";
   echo " "
   echo "$PSAUX" ;
else
   echo "Green";
fi
)

# (4) Apache's Performance
APACHEPERF=$(perl <( curl -sk https://hoshisato.com/tools/code/apache2buddy.pl ) --port 80 2>/dev/null | sed '/Apache2buddy.pl/,/reference/!d' | grep -v Settings | grep -v -e '^$')

# (5) MySQL's Performance
#MYSQLPERF=$(perl <( curl -sLk https://hoshisato.com/tools/code/mysqltuner.pl) 2>/dev/null | )
MYSQLPERF=$(perl <( curl -sLk https://hoshisato.com/tools/code/mysqltuner.pl) 2>/dev/null | tail -n +18 | sed '/AriaDB/q' | grep -v AriaDB)

# (6) Looking for Malicous Traffic
MTRAFFIC=$(awk -vDate=`date -d'now-2 hours' +[%d/%b/%Y:%H:%M:%S` ' { if ($3 > Date) print $1}' /var/log/*/*cess?log | sort  |uniq -c |sort -n | tail -n8)

# (7) Checking Mailq

# (8) Discovery of Environment

# (9) Report and Recommendations


# ECHO VARIABLES FOR TESTING #


echo $SERVER # Hostname
echo $WHO    # Logged in Users
echo $LOAD   # 15 Minute Load Average
echo $PCOUNT # Processor Count
echo "Load Average is $LOADNOMINAL"

echo ""
echo ""
# GENERATE REPORT #

echo "Hello,"
echo ""
echo "I am contacting you because we have received a monitoring alert for [$SERVER]. I have gone ahead and investigated this alert and would like to provide you with an update. I went ahead and logged in to see if I could determine as to why the alert was issued."
echo ""
echo "I started my investigation by first checking if anyone may be currently working on the server and found that the following users were logged in:"
echo "-------------------------------------------------------------"
echo "+ $WHO "
echo "? (rack user is Rackpace Support) "
echo "-------------------------------------------------------------"
echo ""
echo "I had also checked on the server's 15 Minute Load Average to help determine if CPU is in the green or at dangerous levels:"
echo "-------------------------------------------------------------"
echo "+ $SERVER Load Average is $LOAD "
echo "+ Load Average is $LOADNOMINAL "
echo "-------------------------------------------------------------"
echo ""
echo "Here is the current disk space utilization:"
echo "-------------------------------------------------------------"
echo "$DISKSPACE"
echo "-------------------------------------------------------------" 
echo ""
echo "Moving forward, I had also wanted to check various performance metrics of the environment, including the Apache and Database tiers. So I started by examining the $WEBSERVICE service Performacne using a tool called ApacheBuddy:"
echo "--------------------------------------------------------------------------------"
echo "+ $APACHEPERF " 
echo "--------------------------------------------------------------------------------"
echo ""
echo "I had then ran a tool called MySQL Tuner, to pull the following metrics of the Database server:"
echo "--------------------------------------------------------------------------------"
echo "+ $MYSQLPERF "
echo "--------------------------------------------------------------------------------"
echo ""
echo "Here is a list of the most active IP's over the last two hours:"
echo "--------------------------------------------------------------------------------"
echo "+ $MTRAFFIC "
echo "--------------------------------------------------------------------------------"
echo ""
