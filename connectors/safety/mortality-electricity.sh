#!/bin/sh

# Convert CSV to JSON and store to Redis
#
# H. Dahle

TMPDIR=$(mktemp -d)
#DATE=`date --iso-8601='minutes'`
DATE=`date`

for REDISKEY in "mortality-electricity" "mortality-electricity-markandya" "mortality-electricity-sovacool"
do

  CSVFILE="${REDISKEY}.csv"
  JSONFILE="${TMPDIR}/${REDISKEY}.json"

  if [ -f "${CSVFILE}" ]; then
      echo -n "Number of lines in CSV:"
      cat ${CSVFILE} | wc -l
  else
      echo "File not found: ${CSVFILE}, aborting "
      exit 0
  fi

  echo "Converting data to JSON, writing to: ${JSONFILE}"
  awk -v d="${DATE}" 'BEGIN {
                        FS=","; ORS="";
                        print "{"
                        print "\"accessed\":\"" d "\", "
                        NOTFIRST=0
                      }

     /^#/             { next }
     $1 == "source"   { print "\"source\":\"" $2 "\", " ; next }
     $1 == "info"     { print "\"info\":\"" $2 "\", " ; next }
     $1 == "link"     { print "\"link\":\"" $2 "\", " ; next }
     $1 == "data"     { print "\"data\": [" ; next }
     $2 != ""         {
                        if (NOTFIRST) print ", "
                        NOTFIRST=1
                        print "{\"resource\":\"" $1 "\", \"deaths\":" $2 "}" 
                      }
     END              { print "]}" }' < ${CSVFILE} > ${JSONFILE}

  echo -n "JSON byte count:"
  cat ${JSONFILE} | wc --bytes

  # When installing cron job, provde fully qualified filename to this script
  REDIS=$1
  if [ "$REDIS" = "" ]; then
    REDIS="redis-cli"
  else
    if [ ! -f ${REDIS} ]; then
      echo "Redis-executable not found: ${REDIS}, aborting"
      exit
    fi
  fi

  # Save to Redis
  echo -n "Saving to Redis, key=${REDISKEY}, result: "
  ${REDIS} -x set ${REDISKEY} < ${JSONFILE}

  # Quick verification
  echo -n "Retrieving from Redis, JSON byte count:"
  ${REDIS} get ${REDISKEY} | wc --bytes

done
