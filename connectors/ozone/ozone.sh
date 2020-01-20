#!/bin/sh

# Fetch monthly ozone stats from NASA.gov
# Reformat to JSON and store to Redis
#
# H. Dahle

REDISKEY="ozone-nasa"
TMPDIR="/tmp/"

echo "Fetch Ozone data from https://ozonewatch.gsfc.nasa.gov/statistics/annual_data.txt? (y/n)? "
echo "Store to Redis with key ${REDISKEY}"
echo "Temporary files in ${TMPDIR}"
curl "https://ozonewatch.gsfc.nasa.gov/statistics/annual_data.txt" > ${TMPDIR}${REDISKEY}.txt

# Turn it into a JSON blob. Input format in text file:
# Ozone hole area mean (07 September -- 13 October)
# Minimum ozone (21 September -- 16 October)
#O3 Hole Area Minimum Ozone
#Year     (mil km2)          (DU)
#----  ------------ -------------
#1979           0.1         225.0
#1980           1.4         203.0
#1981           0.6         209.5
#1982           4.8         185.0

awk 'BEGIN {ORS="";
            print "{"
            print "\"source\":\"NASA Ozone Watch, https://ozonewatch.gsfc.nasa.gov\", "
            print "\"link\":\"https://ozonewatch.gsfc.nasa.gov/statistics/annual_data.txt\", "
            print "\"info\":\"Data is for Southern Hemisphere."
            print "meanOzoneHoleSize: Ozone hole area mean in millions of square km (07 September -- 13 October). "
            print "minimumOzoneLevel: Minimum ozone in DU Dobson Units (21 September -- 16 October) \", "
            print "\"data\": ["
            NOTFIRST=0
            START=0
           }

     $1 == "----" {START=1;next} # Found trigger for start of data

     START {if (NOTFIRST) print ", "
            NOTFIRST=1
            printf "{\"date\":\"%s-09\",\"meanOzoneHoleSize\":%s,\"minimumOzoneLevel\":%s}",  $1, $2, $3 }
     END   {print "]}"}' < ${TMPDIR}${REDISKEY}.txt > ${TMPDIR}${REDISKEY}.json

# Not really necessary
wc ${TMPDIR}${REDISKEY}.*

# stick it into Redis
echo "Saving to Redis"
redis-cli -x set ${REDISKEY} < ${TMPDIR}${REDISKEY}.json
