#!/bin/sh
#
# Fetch monthly ice extent data from colorado.edu
# There are twelve files per hemisphere, one per month
# Northern hemisphere
# 
# H. Dahle

DATE=`date --iso-8601='minutes'`
FTPURL="ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/"
REDISKEY="ice-nsidc2"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"

echo ${DATE}
echo "Fetch ice-extent data from NSIDC, convert to JSON, store to Redis"
echo "Getting ftp data from sidads.colorado.edu, saving to ${CSVFILE}"

for MONTH in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12"
do
  curl "${FTPURL}N_${MONTH}_extent_v3.0.csv" >> ${CSVFILE}
done

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
# { source: '',
#   license: '',
#   link: '',
#   data: {
#     labels: [],
#     datasets: [
#       label: '',
#       data: []
#     ]
#   }  
# }
# Turn it into a JSON blob

awk -v d="${DATE}" -v FTPURL="${FTPURL}" 'BEGIN {
              ORS=""
              FS=","
              print "{"
              print "\"source\":\"NSIDC National Snow and Ice Data Center, University of Colorado, Boulder. https://nsidc.org \", "
              print "\"link\":\"" FTPURL "\", "
              print "\"info\":\"Minimum sea ice extent is measured in million square kilometers. Sea ice extent is defined as the total area in which ice concentration is at least 15%.\", "
              print "\"license\":\"From https://nsidc.org/about/use_copyright.html : You may download and use photographs, imagery, or text from our Web site, unless limitations for its use are specifically stated. Please credit the National Snow and Ice Data Center as described below.\", "
              print "\"accessed\":\"" d "\", "
            }

     # Skip any comments
     /^#/   { next }

     # Skip the CSV header line
     /year/ { next }

     # Trim off leading whitespace
            { gsub(/^[ \t]+/,"",$3) }
            { gsub(/^[ \t]+/,"",$4) }
            { gsub(/^[ \t]+/,"",$5) }
            { gsub(/^[ \t]+/,"",$6) }

     # Change the -9999 indicator to null
     $3~/\-9999/ { $3 = "null" }
     $5~/\-9999/ { $5 = "null" }
     $6~/\-9999/ { $6 = "null" }

     # The normal case
            { if ($2>12) { print "Error"; next }
              if ($2<1)  { print "Error"; next }
              json[0+$1][0+$2] = $5 
            }

     END    { print "\n\"data\": {"
              print "\n\"labels\": [\"Jan\",\"Feb\",\"Mar\",\"Apr\",\"May\",\"Jun\",\"Jul\",\"Aug\",\"Sep\",\"Oct\",\"Nov\",\"Dec\"],"
              print "\n\"datasets\": ["
              printComma=0        
              for (i in json) {
                if (printComma++) print "," 
                print "\n{"
                print "\"label\":\"" i "\","
                print "\"data\": ["         
                for (j=1; j<13; j++) {
                  if (!(j in json[i])) 
                    print "\"null\""
                  else
                    print "\"" json[i][j] "\"" 
                  if (j<12)
                    print ","
                }
                print "]}"
              } 
              print "]}}" 
            }' < ${CSVFILE} > ${JSONFILE}

# Just for reassurance
echo -n "JSON byte count:"
cat ${JSONFILE} | wc --bytes

# When installing cron job, provde fully qualified filename to this script
# Cron doesnt run with the same PATH as regular user
REDIS=$1
if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
fi

if [ ! `which ${REDIS}` ]; then
  echo "Redis-executable not found: ${REDIS}"
  echo "Saving to ${REDISKEY}.json"
  cp ${JSONFILE} ${REDISKEY}.json
  exit
fi

# Save to redis
echo -n "Saving JSON to Redis, key: ${REDISKEY}: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

# Quick verification
echo -n "Retrieving from Redis, JSON byte count: "
${REDIS} get ${REDISKEY} | wc --bytes
