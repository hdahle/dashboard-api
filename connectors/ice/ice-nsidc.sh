#!/bin/sh
#
# Fetch monthly ice extent data from colorado.edu
# There are twelve files per hemisphere, one per month
# Northern hemisphere
# 
# H. Dahle

REDISKEY="ice-nsidc"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
echo "Fetch ice-extent data from NSIDC, convert to JSON, store to Redis"
echo "Getting ftp data from sidads.colorado.edu, saving to ${CSVFILE}"

curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_01_extent_v3.0.csv > ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_02_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_03_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_04_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_05_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_06_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_07_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_08_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_09_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_10_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_11_extent_v3.0.csv >> ${CSVFILE}
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_12_extent_v3.0.csv >> ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

# Southern hemisphere
# curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/south/monthly/data/S_01_extent_v3.0.csv
# CSV input:
# year, mo,    data-type, region, extent,   area
# 1978, 12,      Goddard,      N,  13.67,  10.90
# 1979, 12,      Goddard,      N,  13.34,  10.63
# 1980, 12,      Goddard,      N,  13.59,  10.78
# 1981, 12,      Goddard,      N,  13.34,  10.54
# 1982, 12,      Goddard,      N,  13.64,  10.88

# JSON output:
# { 'source': '',
#   'license': '',
#   'publisher':'',
#   'data':
#   [
#     { 'region': COL4, 'type': COL3, 'data': [ {'year': COL1, 'extent': COL5, 'area':COL6 }, {...} ],
#     { 'region': COL4, 'type': COL3, 'data': [ {'year': COL3, 'extent': COL5, 'area':COL6 }, {...} ],
#     { ... }
#   ]
# }

# Turn it into a JSON blob

awk -v d="${DATE}" 'BEGIN {
            ORS=""
            FS=","
            print "{"
            print "\"source\":\"NSIDC National Snow and Ice Data Center, University of Colorado, Boulder. https://nsidc.org \", "
            print "\"link\":\"ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data\", "
            print "\"info\":\" \", "
            print "\"license\":\"From https://nsidc.org/about/use_copyright.html : You may download and use photographs, imagery, or text from our Web site, unless limitations for its use are specifically stated. Please credit the National Snow and Ice Data Center as described below.\", "
            print "\"accessed\":\"" d "\", "
            print "\"data\": ["
            FIRSTRECORD=1
     }

     # Skip any comments

     /^#/  { next }

     # Skip the CSV header line

     /year/{ next }

     # Trim off leading whitespace

           { gsub(/^[ \t]+/,"",$3) }
           { gsub(/^[ \t]+/,"",$4) }
           { gsub(/^[ \t]+/,"",$5) }
           { gsub(/^[ \t]+/,"",$6) }

     # Change the -9999 indicator to null

     $3~/\-9999/ { $5="null" }
     $5~/\-9999/ { $5="null" }
     $6~/\-9999/ { $6="null" }

           { if (FIRSTRECORD == 0) print ","
             printf "{\"year\":%d,\"month\":%d,", $1,$2
             printf "\"extent\":%s,\"area\":%s}", $5,$6
             FIRSTRECORD = 0
           }

     END   { print "]}" }' < ${CSVFILE} > ${JSONFILE}

# Just for reassurance
echo -n "JSON byte count:"
cat ${JSONFILE} | wc --bytes

# When installing cron job, provde fully qualified filename to this script
REDIS=$1
if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]; then
    echo "Redis-executable not found: ${REDIS}, not storing in Redis"
    exit
  fi
fi

# Save to redis
echo -n "Saving JSON to Redis, key: ${REDISKEY}: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

# Quick verification
echo -n "Retrieving from Redis, JSON byte count: "
${REDIS} get ${REDISKEY} | wc --bytes
