#!/bin/sh

# Fetch monthly methane stats from Mauna Loa
# curl ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt > co2.txt

REDISKEY="maunaloach4"
TMPDIR=$(mktemp -d)


echo "Getting data from noaa.gov, writing to: ${TMPDIR}/${REDISKEY}.txt"

curl ftp://aftp.cmdl.noaa.gov/products/trends/ch4/ch4_mm_gl.txt > ${TMPDIR}/${REDISKEY}.txt

echo "Converting data to JSON, writing to: ${TMPDIR}/${REDISKEY}.json"

awk 'BEGIN {ORS="";
            print "{"
            print "\"source\":\"https://www.esrl.noaa.gov/gmd/ccgg/trends_ch4/\", "
            print "\"ftp\":\"ftp://aftp.cmdl.noaa.gov/products/trends/ch4/ch4_mm_gl.txt\", "
            print "\"attribution\":"
            print "\"Ed Dlugokencky, NOAA/ESRL (www.esrl.noaa.gov/gmd/ccgg/trends_ch4/)\", "
            print "\"info\":"
            print "\" \", "
            print "\"data\": ["
            NOTFIRST=0
           }
     /^#/  {next}
           {if (NOTFIRST) print ", "
            NOTFIRST=1
            printf "{\"date\":\"%s-%02d\",\"average\":%s,\"trend\":%s}",  $1, $2, $4, $6 }
     END   {print "]}"}' < ${TMPDIR}/${REDISKEY}.txt > ${TMPDIR}/${REDISKEY}.json

echo "JSON byte count:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# Stick it into Redis
echo "Saving to Redis "
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json
# Quick verification
echo "Retrieving from Redis, JSON byte count:"
redis-cli get ${REDISKEY} | wc --bytes

