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
DATE=`date --iso-8601='minutes'`

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

     # save date and value
     # we will do this until we reach end-of-file which is the most recent data
     NF==5 {year= $1; month=$2; day=$3; value=$4 } 
     
     # end of file reached, print most recent data, done
     END   {printf "{ \"date\":\"%04d-%02d-%02d\", \"value\":%.2f  }]}", $1, $2, $3, $4 
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
