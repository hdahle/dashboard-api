#!/bin/sh

# Fetch monthly methane stats from Mauna Loa
# curl ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt > co2.txt
# Convert to JSON and store to Redis
#
# H. Dahle

REDISKEY="maunaloach4"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601=minutes`

echo ${DATE}
echo "Getting ftp data from noaa.gov, writing to: ${CSVFILE}"
curl ftp://aftp.cmdl.noaa.gov/products/trends/ch4/ch4_mm_gl.txt > ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

echo "Converting data to JSON, writing to: ${JSONFILE}"
awk -v d="${DATE}" 'BEGIN {ORS="";
            print "{"
            print "\"source\":"
            print "\"Ed Dlugokencky, NOAA/ESRL, http://www.esrl.noaa.gov/gmd/ccgg/trends_ch4\", "
            print "\"link\":\"ftp://aftp.cmdl.noaa.gov/products/trends/ch4/ch4_mm_gl.txt\", "
            print "\"info\":\"Globally averaged monthly mean CH4 abundance measured from marine surface sites. Numbers are dry air mole fraction in ppb.\", "
            print "\"accessed\":\"" d "\", "
            print "\"data\": ["
            NOTFIRST=0
           }
     /^#/  {next}
           {if (NOTFIRST) print ", "
            NOTFIRST=1
            printf "{\"date\":\"%s-%02d\",\"average\":%s,\"trend\":%s}",  $1, $2, $4, $6 }
     END   {print "]}"}' < ${CSVFILE} > ${JSONFILE}

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

# Save to Redis
echo -n "Saving to Redis, key=${REDISKEY}, result: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

# Quick verification
echo -n "Retrieving from Redis, JSON byte count:"
${REDIS} get ${REDISKEY} | wc --bytes

