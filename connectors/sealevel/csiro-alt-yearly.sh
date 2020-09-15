#!/bin/sh

# Convert CSIRO_Alt_yearly CSV file to JSON and store into Redis
# CSIRO files: ftp://ftp.csiro.au/legresy/gmsl_files
#
# H. Dahle 2020

REDISKEY="CSIRO_Alt_yearly"
TMPDIR=$(mktemp -d)
CSVFILE="${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
echo "Global Sea Level. Converting from CSV to JSON"
echo "Using temporary directory ${TMPDIR}"

#if [ ! -f "${CSVFILE}" ]; then
#  echo -n "File not found: ${CSVFILE}, downloading: "
  curl -s -S "ftp://ftp.csiro.au/legresy/gmsl_files/CSIRO_Alt_yearly.csv" > ${CSVFILE}
#fi

if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 
fi

# CSV format
#Time	GMSL (yearly)
#1993.500,-6
#1994.500,-4.7
#1995.500,-1.8
#1996.500,3.8
#1997.500,8.6
#1998.500,14.4

awk -v d="${DATE}" 'BEGIN {
            ORS=""
            FS="[, \t]+"
            print "{"
            print "\"source\": \"Commonwealth Scientific and Industrial Research Organisation (CSIRO), Australia\", "
            print "\"link\": \"ftp://ftp.csiro.au/legresy/gmsl_files\", "
            print "\"info\": \"Global Mean Sea Levels in mm since 1993. \", "
            print "\"license\": "
            print "\"Creative Commons Attribution 4.0 International Licence\", "
            print "\"accessed\":\"" d "\", "
            print "\"info\":\"x: year, y: global mean sea level in mm\", "
            print "\"data\":["
            FIRST=1
     }

     $1=="Time" {next}

     NF==2 {
            year = substr($1, 1, 4)
            if (!FIRST) print ", "
            FIRST=0
            print "{\"x\":\"" year  "\",\"y\":" $2+0 "}"
     }
     END   {print "]}"}' < ${CSVFILE}  > ${JSONFILE}

# Quick test
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
