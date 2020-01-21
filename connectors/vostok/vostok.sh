#!/bin/sh

# Fetch the Vostok Ice Core 400.000 year CO2 data
# Convert to JSON
# Store to Redis
#
# H. Dahle

VOSTOK="vostok-icecore-co2"
TMPDIR=$(mktemp -d)

echo "Read Vostok CO2 Data, convert to JSON and save to Redis"

if [ -f  "${VOSTOK}.txt" ]; then
    echo "File ${VOSTOK}.txt exists"
else
    echo "Fetching Vostok data from https://cdiac.ess-dive.lbl.gov/ftp/trends/co2/vostok.icecore.co2, save to ${VOSTOK}.txt"
    curl "https://cdiac.ess-dive.lbl.gov/ftp/trends/co2/vostok.icecore.co2" > ${VOSTOK}.txt
fi
wc -l ${VOSTOK}.txt

#Vostok format:
#Mean
#Age of   age of    CO2
#Depth  the ice  the air concentration
#(m)   (yr BP)  (yr BP)  (ppmv)
#
#149.1 5679 2342 284.7
#173.1 6828 3634 272.8
#177.4 7043 3833 268.1
#228.6 9523 6220 262.2

REDISKEY="vostok"

echo "Cleaning Vostok data. Note: The dates in the Vostok are "Years BP" which is years before 1950. Writing to ${TMPDIR}/${REDISKEY}.txt"

awk '/^*/       {next}
     /[A-Za-z]/ {next}
     NF==4      {print 1950-$3 " " $4}' < ${VOSTOK}.txt > ${TMPDIR}/${REDISKEY}.txt

echo "Sort data by year then convert to JSON, writing to ${TMPDIR}/${REDISKEY}.json"

sort -n ${TMPDIR}/${REDISKEY}.txt | awk 'BEGIN {ORS=""
            print "{"
            print "\"source\":\"Barnola, J.-M., D. Raynaud, C. Lorius, and N.I. Barkov. 2003. Historical CO2 record from the Vostok ice core. In Trends: A Compendium of Data on Global Change. Carbon Dioxide Information Analysis Center, Oak Ridge National Laboratory, U.S. Department of Energy, Oak Ridge.\", "
            print "\"link\":\"https://cdiac.ess-dive.lbl.gov/trends/co2/ice_core_co2.html\", "
            print "\"data\": ["
            FIRSTRECORD = 1
     }

     # Skip comments
     /^*/  {next}

     # Skip text
     /[A-Za-z]/ {next}

     NF==2 {if (!FIRSTRECORD) printf ","
            FIRSTRECORD = 0
            printf " {\"x\":%s,\"y\":%s}", $1, $2
     }

     END   {print "]}"}' > ${TMPDIR}/${REDISKEY}.json

# sanity check
echo "Saving JSON, number of bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# save JSON to Redis
echo "Saving to Redis, key ${REDISKEY}"
redis-cli -x SET ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# quick test
echo "Retrieving key=${REDISKEY}, number of bytes:"
redis-cli get ${REDISKEY} | wc --bytes
