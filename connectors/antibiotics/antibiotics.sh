#!/bin/sh
#
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

for REDISKEY in "eu-antibiotics-details-2018" "eu-antibiotics-2018"
do
  TMPDIR=$(mktemp -d)
  CSVFILE="${REDISKEY}.csv"
  JSONFILE="${TMPDIR}/${REDISKEY}.json"
  DATE=`date --iso-8601='minutes'`
  echo ${DATE}
  echo "Converting Europe Veterinary Antimicrobial Usage data from CSV to JSON"
  echo "Using ${REDISKEY}.csv, using tmpdir ${TMPDIR}"

  if [ -f "${CSVFILE}" ]; then
    LINES=`cat ${CSVFILE} | wc -l`
    if [ "$LINES" -eq "0" ]; then
      echo "Error: empty file, aborting"
      exit
    fi
  else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
  fi

  awk -v ACCESSDATE="${DATE}" 'BEGIN {
            ORS = ""
            FS  = ","
            START = 0
            LINE = 0
     }

     $1 == "source"  { SOURCE=$2 ; next }
     $1 == "link"    { LINK=$2 ; next }
     $1 == "Country" { for (i=2; i<=NF; i++) datasetName[i-2] = $i; numDatasets = NF ; next}
     
     NF == numDatasets { 
            for (i=1; i<=NF; i++) dataset[i][LINE] = $i
            LINE++
     }  
     END {  print "{"
            print "\"source\":\"" SOURCE "\", "
            print "\"link\":\"" LINK "\", "
            print "\"accessed\":\"" ACCESSDATE "\", "
            print "\"data\": {"
            print "\"labels\": ["
            for (i=0; i<LINE; i++) {
              if (i) print ","
              print "\"" dataset[1][i] "\""
            }
            print "],"
            print "\"datasets\":["
            for (j=2; j<=numDatasets; j++) {
              if (j>2) print ","
              print "{\"label\":\"" datasetName[j-2] "\", \"data\":["
              for (i=0; i<LINE; i++) {
                if (i) print ","
                print dataset[j][i]
              }
              print "]}"
            }
            print "]}}"
     }' < ${CSVFILE} > ${JSONFILE}

  echo -n "Storing JSON to Redis, bytes: "
  cat ${JSONFILE} | wc --bytes 

  echo -n "Saving JSON to Redis with key ${REDISKEY}, result: "
  ${REDIS} -x set ${REDISKEY} < ${JSONFILE}

  echo -n "Retrieving key=${REDISKEY} from Redis, bytes: "
  ${REDIS} get ${REDISKEY} | wc --bytes

done
