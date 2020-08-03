#!/bin/bash
INSTANCE_ID=`curl --silent http://169.254.169.254/latest/meta-data/local-ipv4`
Bucket=goibibo-logs-archive-m

logpath="/var/log/containers/`echo $HOSTNAME`*.log"

logfile=`echo $logpath|tr -s ' ' '\n' | grep -v sidecar | grep -v init-sysctl`

echo $logfile

CopyFiles(){
for file in $logfile
    do
          aws s3 cp ${file}-${INSTANCE_ID}`date +"-%Y-%m-%d-%H-%M" `.gz s3://${Bucket}/provider=${provider}/years=`date +"%Y" `/months=`date +"%Y%m" `/days=`date +"%Y%m%d" `/hours=`date +"%H" `/ --region ap-south-1 --output text
done
                   }
# Rotate Files
for file in $logfile
    do
        if [ ! -f $file ] || [ ! -s $file ]; then
        echo "log file not found or empty : $file"
        else
        timestamp=`date +"%Y-%m-%d-%H-%M"`
        newlogfile=$file-${INSTANCE_ID}-$timestamp
        cp $file $newlogfile
        cat /dev/null > $file
        fi
# Zip files & CleanUp
         cleauptimestamp=`date +"%Y-%m-%d-%H" -d "3 hour ago"`
         #cleauptimestamp=`date +"%Y-%m-%d-%H" --date="1days ago"`
         deletefilename=$file-${INSTANCE_ID}-$cleauptimestamp
         rm -f $deletefilename*
        # timestamp=`date +"%Y-%m-%d-%H" -d "1 hour ago"`
        #newlogfile=$file-${INSTANCE_ID}-$timestamp
         pigz -f --fast $newlogfile
done
for file in $logfile
    do
provider=`echo $HOSTNAME | awk 'NF{NF-=2}1' FS='-' OFS='-'`
logfile=$file
CopyFiles
done
