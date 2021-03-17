#!/bin/sh

# Svalbard Lufthavn time series

# CSV input:
# Navn;Stasjon;Tid(norsk normaltid);Homogenisert middeltemperatur (år)
# Svalbard Lufthavn;SN99840;1899;-7,6
# Svalbard Lufthavn;SN99840;1900;-8,1
# Svalbard Lufthavn;SN99840;1901;-7,7
#
# JSON output:
# { 'source': '',
#   'license': '',
#   'link':
#   'data':
#   [
#     {'x': $3, 'y': $4 }, { ... },  ]
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
cat ${REDISKEY}.csv | sed s/,/./ | awk 'BEGIN {ORS=""
            FS=";"
            print "{"
            print "\"source\":\"The Norwegian Meteorological Institute and The Norwegian Centre for Climate Services NCCS\", "
            print "\"license\":\"CC BY 4.0 \", "
            print "\"link\":\"https://seklima.met.no/observations\", "
            print "\"info\":\"Annual mean temperatures at Svalbard Lufthavn/Svalbard Airport\", "
            print "\"data\": ["
            SEP=""
     }
     $1 == "Svalbard Lufthavn" {
            printf "%s{\"x\":%s,\"y\":%s}", SEP, $3, $4
            SEP = ","
     }
     END   {print "]}"}' > ${TMPDIR}/${REDISKEY}.json


echo "Saving JSON to Redis, bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# stick it into Redis
echo "Saving JSON to Redis with key: ${REDISKEY}"
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# quick sanity check
echo "Retrieving key=${REDISKEY} from Redis, bytes:"
redis-cli get ${REDISKEY} | wc --bytes
