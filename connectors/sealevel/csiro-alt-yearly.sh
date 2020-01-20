#!/bin/sh

# Convet CSIRO CSV file to JSON and store into Redis
# Note that CSV file must be manually downloaded

# Input CSV Format
#==> CSIRO_Recons.csv <==
#"Time","GMSL (mm)","GMSL uncertainty (mm)"
#1880.5, -157.1,   24.2
#1881.5, -151.5,   24.2
#1882.5, -168.3,   23.0

# JSON Output Format

REDISKEY="CSIRO_Alt_yearly"
TMPDIR=$(mktemp -d)

if [ -f "${REDISKEY}.csv" ]; then
    echo "Input file found"
else
    echo "Input file not found: ${REDISKEY}.csv, aborting"
    exit
fi

awk 'BEGIN {ORS="";
            FS=",";
            print "{"
            print "\"source\": \"Commonwealth Scientific and Industrial Research Organisation (CSIRO), Australia\", "
            print "\"link\": \"ftp://ftp.csiro.au/legresy/gmsl_files\", "
            print "\"info\": \"Global Mean Sea Levels in mm since 1993. \", "
            print "\"license\": "
            print "\"Creative Commons Attribution 4.0 International Licence\", "
            print "\"data\": [{\"region\":\"global\", \"data\":["
            FIRST=1
     }

     NF!=2 {next}
     /Time/ {next}

     {
            if (!FIRST) print ", "
            FIRST=0
            printf "{\"year\":\"%d\",\"data\":%.1f}", $1, $2
     }
     END   {print "]}]}"}' < ${REDISKEY}.csv  > ${TMPDIR}/${REDISKEY}.json

# Quick test
echo "Storing JSON, number of bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# stick it into Redis
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# Quick verification
echo "Retrieving JSON from Redis, bytes:"
redis-cli get ${REDISKEY} | wc --bytes

