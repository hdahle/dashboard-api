#!/bin/sh

# CCS Projects Worldwide 
# Convert CSV file to JSON, store to Redis
#
# H. Dahle, 2021

for REDISKEY in "operational-ccs-2019" "operational-ccs-2020" ;
do

TMPDIR=$(mktemp -d)
CSVFILE="${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

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

awk -v d="${DATE}" 'BEGIN {
            ORS = ""
            FS  = ","
            line = 0;
     }
     $1 == "License" { license = $2 ; next }
     $1 == "Source"  { source = $2 ; next }
     $1 == "Link"    { link = $2 ; next }
     $2 == "Country" { next }

     NF == 5 {
            labels[line] = $1 " " $2
            data[line] = $4
            color[line] = ($5 == "EOR") ? "red" : (($5 == "Suspended") ? "grey" : "green")  
            line++
     }

     END {  print "{"
            print "\"source\":\"" source "\", "
            print "\"license\":\"" license "\", "
            print "\"link\":\"" link "\", "
            print "\"info\": \"Operational large scale CCS projects\", "
            print "\"accessed\":\"" d "\","
            print "\"data\":{"
            print "\"labels\":["
            printComma = 0
            for (i in labels) {
                   if (printComma++) print ","
                   print "\"" labels[i] "\""
            }
            print "],"
            print "\"datasets\":[{"
            print "\"data\":["
            printComma = 0
            for (i in data) {
                   if (printComma++) print ","
                   print "\"" data[i] "\""
            }
            print "],"
            print "\"backgroundColor\":["
            printComma = 0
            for (i in color) {
                   if (printComma++) print ","
                   print "\"" color[i] "\""
            }
            print "]}]}}\n"

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

done