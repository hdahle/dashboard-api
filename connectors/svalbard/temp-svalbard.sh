#!/bin/sh

# Svalbard Lufthavn time series

# CSV input:
# name,station,time,id,best_estimate_mean(air_temperature P1Y)
# Svalbard Lufthavn,SN99840,1899,0,"-7,8"
# Svalbard Lufthavn,SN99840,1900,1,"-8,1"
# Svalbard Lufthavn,SN99840,1901,2,"-7,7"

# Entity,Code,Year,Median (℃),Upper (℃),Lower (℃)
# Global,,1850,-0.373,-0.339,-0.425
# Global,,1851,-0.218,-0.184,-0.274
# Global,,1852,-0.228,-0.196,-0.28
# Northern Hemisphere,,2002,0.593,0.627,0.562
# Northern Hemisphere,,2003,0.642,0.679,0.608
# Northern Hemisphere,,2004,0.604,0.636,0.571

# JSON output:

# { 'source': '',
#   'license': 'https://ourworldindata.org/about: Feel free to make use of anything you find here.'
#   'link':
#   'data':
#   [
#     { 'region': $1, 'data': [ {'year': $3, 'temperature': $5 }, { ... }] }
#     { 'region': ... }
#   ]
# }


# Turn it into a JSON blob

REDISKEY="temperature-svalbard"
TMPDIR=$(mktemp -d)

echo "Converting Svalbard temperature data to JSON, store in Redis"

if [ -f "${REDISKEY}.csv" ]; then
    echo "Reading file: ${REDISKEY}.csv"
else
    echo "File not found: ${REDISKEY}.csv, abort"
    exit
fi

echo "Writing file: ${TMPDIR}/${REDISKEY}.json"

# Convert CSV-to-JSON
awk 'BEGIN {ORS=""
            FS=","
            COUNTRY=""
            print "{"
            print "\"source\":\"The Norwegian Meteorological Institute and THe Norwegian Centre for Climate Services NCCS\", "
            print "\"license\":\"CC BY 4.0 \", "
            print "\"link\":\"https://seklima.met.no/observations\", "
            print "\"data\": ["
            FIRSTRECORD=1
     }

     $2 == "station" {next}
     /Meteorologisk institutt/ {next}

     # We are continuing with a country data set
     COUNTRY == $1 {
            if ($6 == "") {
              printf ",{\"year\":%s,\"temperature\":\"%s\"}", $3, $5
            } else {
              printf ",{\"year\":%s,\"temperature\":%s.%s}", $3, $5, $6
            }
            next
     }

     # We are starting a new country data set

     {      if (!FIRSTRECORD) printf "]},"
            if ($6 == "") {
            printf "{\"country\":\"%s\",\"data\":[{\"year\":%s,\"temperature\":\"%s\"}", $1, $3, $5
            } else {
            printf "{\"country\":\"%s\",\"data\":[{\"year\":%s,\"temperature\":%s.%s}", $1, $3, $5, $6
            }
            COUNTRY = $1
            FIRSTRECORD = 0
     }

     END   {print "]}]}"}' < ${REDISKEY}.csv > ${TMPDIR}/${REDISKEY}.json


echo "Saving JSON to Redis, bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# stick it into Redis
echo "Saving JSON to Redis with key: ${REDISKEY}"
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# quick sanity check
echo "Retrieving key=${REDISKEY} from Redis, bytes:"
redis-cli get ${REDISKEY} | wc --bytes
