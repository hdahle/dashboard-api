#!/bin/sh

# Fetch temperature data from UAH University of Alabama Huntsville
# Convert to JSON and store to Redis
#
# H. Dahle

REDISKEY="global-temperature-uah"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
echo "Getting data from uah, saving to ${CSVFILE}"
curl "https://www.nsstc.uah.edu/data/msu/v6.0/tlt/uahncdc_lt_6.0.txt" > ${CSVFILE}
 
if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

# CSV format
# Year Mo Globe  Land Ocean   NH   Land Ocean   SH   Land Ocean Trpcs  Land Ocean NoExt  Land Ocean SoExt  Land Ocean NoPol  Land Ocean SoPol  Land Ocean USA48 USA49  AUST
# 1978 12 -0.36 -0.36 -0.36 -0.31 -0.30 -0.32 -0.41 -0.49 -0.39 -0.47 -0.49 -0.47 -0.23 -0.27 -0.20 -0.37 -0.41 -0.36 -0.24 -0.55  0.12 -0.35 -0.21 -0.42 -1.03 -0.94 -1.19
# 1979  1 -0.33 -0.48 -0.27 -0.48 -0.69 -0.35 -0.18 -0.00 -0.22 -0.37 -0.42 -0.36 -0.54 -0.75 -0.35 -0.08  0.26 -0.15 -0.11 -0.65  0.51 -0.11 -0.08 -0.12 -3.07 -2.25  1.16
# 1979  2 -0.27 -0.35 -0.24 -0.25 -0.32 -0.21 -0.29 -0.41 -0.27 -0.23 -0.09 -0.27 -0.27 -0.40 -0.16 -0.31 -0.58 -0.27 -1.71 -2.06 -1.32 -0.68 -1.09 -0.49 -1.55 -1.59 -0.20
# 1979  3 -0.26 -0.31 -0.24 -0.28 -0.25 -0.29 -0.24 -0.44 -0.19 -0.26 -0.30 -0.25 -0.30 -0.25 -0.34 -0.21 -0.50 -0.16 -0.32 -0.26 -0.39 -0.47 -1.20 -0.13 -0.43 -0.15  0.42
# ...
# 2020  1  0.56  0.69  0.52  0.60  0.66  0.56  0.53  0.74  0.49  0.62  0.63  0.61  0.59  0.69  0.50  0.49  0.80  0.43  0.12  0.20  0.03  0.78  0.95  0.70  0.73  0.27  0.66
# Year Mo Globe  Land Ocean   NH   Land Ocean   SH   Land Ocean Trpcs  Land Ocean NoExt  Land Ocean SoExt  Land Ocean NoPol  Land Ocean SoPol  Land Ocean USA48 USA49  AUST
# 
# Trend    0.13  0.18  0.11  0.16  0.19  0.14  0.11  0.16  0.10  0.13  0.16  0.12  0.18  0.20  0.16  0.10  0.15  0.09  0.25  0.23  0.28  0.02  0.10 -0.02  0.17  0.18  0.19
# 
#  NOTE:  Version 6.0 as of April 2015
#  NOTE:  New Reference for annual cycle 1981-2010
#  NOTE:  Version 5.6 as of Jun 2013
# 
#  GL 90S-90N, NH 0-90N, SH 90S-0, TRPCS 20S-20N
#  NoExt 20N-90N, SoExt 90S-20S, NoPol 60N-90N, SoPol 90S-60S
 
echo "Converting data to JSON, saving to ${JSONFILE}"
awk -v d="${DATE}" 'BEGIN {
            ORS="";FS=" ";
            print "{"
            print "\"source\":\"NSSTC National Space Science and Technology Center, University of Alabama in Huntsville\", "
            print "\"license\":\"  \", "
            print "\"link\":\"https://www.nsstc.uah.edu/data/msu/v6.0/tlt\", "
            print "\"accessed\":\"" d "\", "
            print "\"data\": ["
            NOTFIRST=0
           }
     /^#/  {next}
     $1 == "Year" { next}

     NF == 29 {
            if (NOTFIRST) print ", "
            NOTFIRST=1
            printf "{\"t\":\"%d-%02d\",\"y\":%.2f}", $1,$2,$3
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
