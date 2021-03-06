#!/bin/sh

# Fetch daily CO2 data from NOAA.GOV
# Convert to JSON and store to Redis
# Only the most recent day (yesterday) is saved
#
# H. Dahle

REDISKEY="maunaloaco2-daily"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date +'%Y-%m-%d'`

echo ${DATE}
echo "Getting ftp data from noaa.gov, saving to ${CSVFILE}"
curl ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_trend_gl.txt > ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

echo "Converting data to JSON, saving to ${JSONFILE}"
awk -v d="${DATE}" 'BEGIN {ORS="";
            split(d,ymd,"-")
            print "{"
            print "\"source\":"
            print "\"Dr. Pieter Tans, NOAA/ESRL (www.esrl.noaa.gov/gmd/ccgg/trends/) and "
            print "Dr. Ralph Keeling, Scripps Institution of Oceanography (scrippsco2.ucsd.edu/)\", "
            print "\"link\":\"ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_trend_gl.txt\", "
            print "\"accessed\":\"" d "\", "
            print "\"data\": ["
           }

     # Skip comments      
     /^#/  {next}

     # find the CO2 value 1 year ago
     NF==5 && $1==(ymd[1]-1) && $2==(ymd[2]+0) && $3==(ymd[3]+0) {
            lastYr = $4
     } 

     # find the CO2 value 10 years ago
     NF==5 && $1==(ymd[1]-10) && $2==(ymd[2]+0) && $3==(ymd[3]+0) {
            tenYrs = $4
     } 

     # just keep recording and overwriting date and value
     # we will do this until we reach end-of-file which is the most recent data
     NF==5 {year= $1; month=$2; day=$3; value=$4 } 
     
     # end of file reached, print data, done
     END   {
            printf "{\"date\":\"%04d-%02d-%02d\", \"value\":%.2f, \"valueLastYear\":%.2f, \"value10yrsAgo\":%.2f,", $1, $2, $3, $4, lastYr, tenYrs
            printf "\"change1yr\":%.2f, \"change10yr\":%.2f", 100*($4-lastYr)/lastYr, 100*($4-tenYrs)/tenYrs
            printf "}]}"
     }' < ${CSVFILE} > ${JSONFILE}

# Just for reassurance
echo -n "JSON byte count:"
cat ${JSONFILE} | wc --bytes


# When installing cron job, provde fully qualified filename to this script
REDIS=$1
if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]; then
    echo "Redis-executable not found: ${REDIS}, not storing in Redis"
    exit
  fi
fi

# Save to redis
echo -n "Saving JSON to Redis, key: ${REDISKEY}: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

# Quick verification
echo -n "Retrieving from Redis, JSON byte count: "
${REDIS} get ${REDISKEY} | wc --bytes
