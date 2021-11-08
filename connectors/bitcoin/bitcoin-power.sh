#!/bin/sh
#
# Fetch Bitcoin powr consumption estimates from https://cbeci.rog/api/csv
# Convert CSV file to JSON
# Store JSON in Redis
#
# H. Dahle, 2021

REDIS=$1

if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]; then
    echo "Not found: ${REDIS}"
    exit
  fi
fi

REDISKEY="bitcoin-power"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`
echo ${DATE}
echo "Converting Bitcoin power consumption data from CSV to JSON"
echo "Downloading ${REDISKEY}.csv, using tmpdir ${TMPDIR}"
curl --silent --show-error "https://ccaf.io/cbeci/api/csv" > ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
    echo -n "Downloaded CSV-file, lines: "
    cat ${CSVFILE} | wc -l    
    LINES=`cat ${CSVFILE} | wc -l`
    if [ "$LINES" -eq "0" ]; then
      echo "Error: nothing downloaded, aborting"
      exit
    fi
    # grep 2020 ${CSVFILE} 
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

# CSV input:

# Timestamp,Date and Time,MAX,MIN,GUESS
# 1444435200,2015-10-10T00:00:00,3.48537,1.0473,2.15567
# 1444521600,2015-10-11T00:00:00,3.4819,1.04626,2.15352


# JSON output:

# { 'link': 'http://cbeci.org',
#   'license': 'Unknown. Public data source',
#   'source': 'University of Cambridge, Judge Business School, Cambridge Centre for Alternative Finance',
#   'reference': '',
#   'accessed': '<date of access>'
#   'data':
#   [
#     { 't': COL2, 'y':COL5, 'max': COL3, 'min': COL4 },
#     {},...
#   ]
# }


awk -v ACCESSDATE="${DATE}" 'BEGIN {
            ORS = ""
            FS  = ","
            RS  = "\r"
            print "{"
            print "\"source\":\"Cryptocurrency and Blockchain Programme Team (Michel Rauchs, Apolline Blandin, Anton Dek, and Yue Wu) at the Cambridge Centre for Alternative Finance, University of Cambridge, Judge Business School\", "
            print "\"link\":\"https://cbeci.org \", "
            print "\"license\":\"Unknown, publicly available data\", "
            print "\"info\":\"Numbers are annualized power consumption in TWh, assuming miners use a basket of profitable hardware\", "
            print "\"accessed\":\"" ACCESSDATE "\", "
            print "\"data\": { "
            print "\"datasets\": [{ "
            print "\"label\":\"Bitcoin electricity usage, TWh\","
            print "\"data\": ["
            STATE = 0
     }

     # STATE 0: Wait for "Timestamp" to appear in COLUMN 1. When found, go to STATE 1
     $1 == "Timestamp" { STATE = 1; next }

     # STATE 2: Print a comma between objects in array. This special case ensures no comma is printed before first object
     STATE == 2 && NF == 5 { print "," }

     # STATE 1 and 2: Print an object, If in STATE 1, go to STATE 2
     NF == 5 {
            printf "{ \"t\":\"%s\", \"y\":%.2f }", substr($2,1,10), $5
            STATE = 2
     }  

     END {  if (STATE == 0) print "Error: No CSV header found"
            if (STATE == 1) print "Error: CSV header found, but no data found"
            if (STATE == 2) print "]}]}}"  
            if (STATE < 0 || STATE > 2) print "Error: In an unexpected state...panic"
     }' < ${CSVFILE} > ${JSONFILE}

echo -n "Storing JSON to Redis, bytes: "
cat ${JSONFILE} | wc --bytes 

echo -n "Saving JSON to Redis with key ${REDISKEY}, result: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

echo -n "Retrieving key=${REDISKEY} from Redis, bytes: "
${REDIS} get ${REDISKEY} | wc --bytes
