#!/bin/sh

# Fetch temperature data from UK Met Office / Hadley
# Convert to JSON and store to Redis
#
# 2023-08-28: Use HadCRUT5 dataset instead of HadCRUT4 (deprecated)
#
# H. Dahle

REDISKEY="global-temperature-hadcrut"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
echo "Getting ftp data from crudata.uea.ac.uk, saving to ${CSVFILE}"
# curl "https://crudata.uea.ac.uk/cru/data/temperature/HadCRUT4-gl.dat" > ${CSVFILE}
curl "https://crudata.uea.ac.uk/cru/data/temperature/HadCRUT5.0Analysis_gl.txt" > ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

# CSV format: year + 12 months + annual:
# We skip every other line, the lines which have 13 columns
#
# 1851 -0.296 -0.356 -0.479 -0.441 -0.295 -0.197 -0.212 -0.157 -0.101 -0.057 -0.020 -0.051 -0.218
# 1851     23     22     20     21     20     21     22     23     19     20     18     20
# 1852 -0.315 -0.477 -0.502 -0.557 -0.211 -0.040 -0.018 -0.202 -0.125 -0.216 -0.193  0.073 -0.228
# 1852     23     22     22     23     23     24     23     24     21     22     22     25
# 1853 -0.182 -0.327 -0.309 -0.355 -0.268 -0.175 -0.059 -0.148 -0.404 -0.362 -0.255 -0.437 -0.269
 
echo "Converting data to JSON, saving to ${JSONFILE}"
awk -v d="${DATE}" 'BEGIN {
            ORS="";FS=" ";
            print "{"
            print "\"source\":\"HadCRUT5 Dataset, Climatic Research Unit, University of East Anglia, UK\", "
            print "\"license\":\"These datasets are made available under the Open Database License. "
            print "Any rights in individual contents of the datasets are licensed under the "
            print "Database Contents License under the conditions of Attribution and Share-Alike. "
            print "Please use the attribution Climatic Research Unit, University of East Anglia\", "
            print "\"link\":\"https://crudata.uea.ac.uk/cru/data/temperature/HadCRUT5.0Analysis_gl.txt\", "
            print "\"accessed\":\"" d "\", "
            print "\"legend\":\"The temperature data is organized in year/value pairs: [ {y:year, x:annualMean}, ... ] \", "
            print "\"info\":\"Land temperature data is based on measurements at 4800 stations across the world. "
            print "Sea surface temperatures are measured by merchant ships and buoy (fixed and floating)\", "
            print "\"data\": ["
            NOTFIRST=0
           }
     /^#/  {next}
     NF == 14 {
            if (NOTFIRST) print ", "
            NOTFIRST=1
            print "{\"x\":" $1 ",\"y\":" $14 " }"
          }
     END  { print "]}" }' < ${CSVFILE} > ${JSONFILE}

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
