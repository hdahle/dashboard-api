#!/bin/sh

# CCS Projects Worldwide 2019
# Convert CSV file to JSON, store to Redis
#
# H. Dahle, 2020

REDISKEY="operational-ccs"
TMPDIR=$(mktemp -d)
CSVFILE="${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
 
if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

# CSV input:
# License,Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License,,,
# Source,Global CCS Institute 2019. The Global Status of CCS: 2019. Australia.,,,
# Name,Country,Year ,Capacity Mt,Destination
# Gorgon,Australia,2019,4,Storage
# Jilin Oil Field,China,2018,0.6,EOR
# Illinois Industrial CCS,USA,2017,1,Storage
# Petra Nova USA,USA,2017,1.4,EOR

# Turn it into a JSON blob
echo "Converting to JSON, saving to ${JSONFILE}"

awk -v d="${DATE}" 'BEGIN {ORS=""
            FS=","
            START=0
            print "{"
            print "\"info\": \"Operational large scale CCS projects end of 2019\", "
            print "\"accessed\":\"" d "\", "
     }

     $1 == "License" {
            printf "\"license\": \"%s\", ", $2
            next
     }

     $1 == "Source" {
            printf "\"source\": \"%s\", ", $2
            next
     }

     $1 == "Link" {
            printf "\"link\": \"%s\", ", $2
            next
     }

     $2 == "Country" {
            START = 1;
            print "\"data\": ["
            next
     }

     START == 1  {
              print "{"
              printf "\"project\":\"%s\"," , $1
              printf "\"country\":\"%s\"," , $2
              printf "\"year\":\"%s\","    , $3
              printf "\"capacity\":\"%s\",", $4
              printf "\"type\":\"%s\"},"   , $5
     }

     END {  print "{\"project\":null}]}"
     }' < ${CSVFILE} > ${JSONFILE}

# Just for reassurance
echo -n "JSON byte count:"
cat ${JSONFILE} | wc --bytes

# Save to redis
echo -n "Saving JSON to Redis, key: ${REDISKEY}, result: "
redis-cli -x set ${REDISKEY} < ${JSONFILE}

# Quick verification
echo -n "Retrieving from Redis, JSON byte count: "
redis-cli get ${REDISKEY} | wc --bytes

