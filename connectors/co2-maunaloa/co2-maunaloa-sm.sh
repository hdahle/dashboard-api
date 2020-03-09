#!/bin/sh

# Fetch CO2 data from NOAA.GOV
# Convert to JSON and store to Redis
#
# H. Dahle

REDISKEY="maunaloaco2-sm"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
echo "Getting ftp data from noaa.gov, saving to ${CSVFILE}"
curl ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt > ${CSVFILE}

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
            print "\"link\":\"ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt\", "
            print "\"info\":"
            print "\"Before the Industrial Revolution in the 19th century, global average CO2 was about 280 ppm. "
            print "During the last 800,000 years, CO2 fluctuated between about 180 ppm during ice ages and "
            print "280 ppm during interglacial warm periods.\", "
            print "\"accessed\":\"" d "\", "
            print "\"data\": ["
            NOTFIRST=0
           }
     /^#/  {next}
           {if (NOTFIRST) print ", "
            NOTFIRST=1
            # printf "{\"date\":\"%s-%02d\",\"average\":%s,\"interpolated\":%s,\"trend\":%s}",  $1, $2, $4, $5, $6 }
            printf "{\"t\":\"%s-%02d-15\",\"y\":%s}",  $1, $2, $5 }
     END   {print "]}"}' < ${CSVFILE} > ${JSONFILE}

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
