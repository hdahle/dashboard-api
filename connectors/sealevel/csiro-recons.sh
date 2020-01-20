#!/bin/sh

# Global Mean Sea Levels since 1880
# The data files are available at https://research.csiro.au/slrwavescoast/?ddownload=327
# This is a big ZIP archive, with the relevant CSV data file somewhere inside
# Manually save the relevant CSV file, and then run this script to create JSON data and store in Redis

# Input CSV Format
#==> CSIRO_Recons.csv <==
#"Time","GMSL (mm)","GMSL uncertainty (mm)"
#1880.5, -157.1,   24.2
#1881.5, -151.5,   24.2
#1882.5, -168.3,   23.0

# JSON Output Format

REDISKEY="CSIRO_Recons"
TMPDIR=$(mktemp -d)

echo "Global Sea Level. Converting from CSV to JSON"
echo "Download and extract CSV from ZIP  at https://research.csiro.au/slrwavescoast/sea-level/measurements-and-data/sea-level-data/"
echo "Using file ${REDISKEY}.csv"
echo "Using temporary directory ${TMPDIR}"

# Make sure file exists before we start
if [ -f "${REDISKEY}.csv" ]; then
    echo "Found input file"
else
    echo "File ${REDISKEY}.csv not found. Abort"
    exit
fi

# Convert from CSV to JSON
awk 'BEGIN {ORS="";
            FS=",";
            print "{"
            print "\"source\": \"Commonwealth Scientific and Industrial Research Organisation (CSIRO), Australia.Church, John; White, Neil (2016): Reconstructed Global Mean Sea Level for 1870 to 2001. v2. \", "
            print "\"link\": \"https://research.csiro.au/slrwavescoast/sea-level/measurements-and-data/sea-level-data/\", "
            print "\"attribution\": "
            print "\"Church, John; White, Neil (2016): Reconstructed Global Mean Sea Level for 1870 to 2001. v2. CSIRO. Data Collection. https://doi.org/10.4225/08/57BF859E3ACE4\", "
            print "\"info\": \"This file contains the monthly Global Mean Sea Level (GMSL) time series as shown on figure 2 of Church and White (2006). The sea level was reconstructed as described in Church et al (2004). \", "
            print "\"license\": "
            print "\"Creative Commons Attribution 4.0 International Licence\", "
            print "\"data\": [{\"region\":\"global\", \"data\":["
            FIRST=1
     }

     NF!=3 {next}
     /Time/ {next}

     {
            if (!FIRST) print ", "
            FIRST=0
            printf "{\"year\":\"%d\",\"data\":%.1f,\"uncertainty\":%.1f}", $1, $2, $3
     }
     END   {print "]}]}"}' < ${REDISKEY}.csv  > ${TMPDIR}/${REDISKEY}.json


# Just some reassurance
echo "Saving JSON data, bytes"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# stick it into Redis
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# Quick verification
echo "Retrieving from Redis, number of bytes:"
redis-cli get ${REDISKEY} | wc --bytes
