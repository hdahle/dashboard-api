#!/bin/sh

# Svalbard Lufthavn time series

# CSV input:
# name,station,time,id,best_estimate_mean(air_temperature P1Y)
# Svalbard Lufthavn,SN99840,1899,0,"-7,8"
# Svalbard Lufthavn,SN99840,1900,1,"-8,1"
# Svalbard Lufthavn,SN99840,1901,2,"-7,7"

# JSON output:
# { 'source': '',
#   'license': '',
#   'link':
#   'data':
#   [
#     { 'region': $1, 'data': [ {'year': $3, 'temperature': $5 }, { ... }] }
#     { 'region': ... }
#   ]
# }

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
            print "\"source\":\"The Norwegian Meteorological Institute and The Norwegian Centre for Climate Services NCCS\", "
            print "\"license\":\"CC BY 4.0 \", "
            print "\"link\":\"https://seklima.met.no/observations\", "
            print "\"info\":\"Annual mean temperatures at Svalbard Lufthavn/Svalbard Airport\", "
            print "\"data\": ["
            SEP=""
     }

     $2 == "station" {next}
     /Meteorologisk institutt/ {next}

     $1 == "Svalbard Lufthavn" {
            if ($6 == "") {
              printf "%s{\"x\":%s,\"y\":\"%s\"}", SEP, $3, $5
            } else {
              printf "%s{\"x\":%s,\"y\":%s.%s}", SEP, $3, $5, $6
            }
            SEP = ","
     }

     END   {print "]}"}' < ${REDISKEY}.csv > ${TMPDIR}/${REDISKEY}.json


echo "Saving JSON to Redis, bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# stick it into Redis
echo "Saving JSON to Redis with key: ${REDISKEY}"
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# quick sanity check
echo "Retrieving key=${REDISKEY} from Redis, bytes:"
redis-cli get ${REDISKEY} | wc --bytes
