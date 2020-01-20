#!/bin/sh

# Fetch CO2 data from NOAA.GOV
# Convert to JSON and store to Redis
#
# H. Dahle

REDISKEY=maunaloaco2
TMPDIR=$(mktemp -d)

echo "Fetch monthly stats from Mauna Loa, saving to ${REDISKEY}.txt"
echo "Using tempdir ${TMPDIR}"

curl ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt > ${TMPDIR}/${REDISKEY}.txt

echo "Converting data to JSON, saving to ${TMPDIR}/${REDISKEY}.json"

awk 'BEGIN {ORS="";
            print "{"
            print "\"source\":\"www.esrl.noaa.gov/gmd/ccgg/trends/\", "
            print "\"ftp\":\"ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt\", "
            print "\"attribution\":"
            print "\"Dr. Pieter Tans, NOAA/ESRL (www.esrl.noaa.gov/gmd/ccgg/trends/) and "
            print "Dr. Ralph Keeling, Scripps Institution of Oceanography (scrippsco2.ucsd.edu/)\", "
            print "\"historical\":"
            print "\"Before the Industrial Revolution in the 19th century, global average CO2 was about 280 ppm. "
            print "During the last 800,000 years, CO2 fluctuated between about 180 ppm during ice ages and "
            print "280 ppm during interglacial warm periods.\", "
            print "\"data\": ["
            NOTFIRST=0
           }
     /^#/  {next}
           {if (NOTFIRST) print ", "
            NOTFIRST=1
            printf "{\"date\":\"%s-%02d\",\"average\":%s,\"interpolated\":%s,\"trend\":%s}",  $1, $2, $4, $5, $6 }
     END   {print "]}"}' < ${TMPDIR}/${REDISKEY}.txt > ${TMPDIR}/${REDISKEY}.json

echo "JSON byte count:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

echo "Saving JSON to Redis, key: ${REDISKEY}"
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

echo "Retrieving from Redis, JSON byte count:"
redis-cli get ${REDISKEY} | wc --bytes
