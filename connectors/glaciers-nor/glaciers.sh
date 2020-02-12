#!/bin/sh

# Read glacier data from CSV
# Convert to JSON and store to Redis
#
# H. Dahle

for FILE in *.csv ; do
  
  # It would be surprising if file not not found
  if [ ! -f "$FILE" ]; then
    echo "File not found $FILE"
    exit
  fi

  # Extract name of glacier from filename
  GLACIER=`echo "$FILE" | awk -F_ '{print substr($NF,1,index($NF, ".csv")-1)}'`
  echo $GLACIER


  REDISKEY="glacier-length-nor-${GLACIER}"
  TMPDIR=$(mktemp -d)
  CSVFILE="${FILE}"
  JSONFILE="${TMPDIR}/${REDISKEY}.json"
  DATE=`date --iso-8601='minutes'`


  if [ -f "${CSVFILE}" ]; then
      echo -n "Number of lines in CSV:"
      cat ${CSVFILE} | wc -l
  else
      echo "File not found: ${CSVFILE}, aborting "
      exit 0
  fi

  echo "Converting data to JSON, saving to ${JSONFILE}"
  cat ${CSVFILE} | awk -v d="${DATE}" -v g="${GLACIER}" 'BEGIN {ORS=""; IRS="\r";  FS=";"
            print "{"
            print "\"source\":\"NVE, The Norwegian Water Resources and Energy Directorate\", "
            print "\"link\":\"http://glacier.nve.no/glacier/viewer/ci/no/\", "
            print "\"accessed\":\"" d "\", "
            print "\"glacier\":\"" g "\", " 
            print "\"data\": ["
            NOTFIRST=0
           }

     /^#/        { next }
     /Year/      { next }
     $3=="Start" { $3=0 }

           {
            if (NOTFIRST) print ", "
            NOTFIRST=1
            print "{\"x\":" $1 ",\"y\":" ($3+0) "}"
           }
     END   {print "]}"}' > ${JSONFILE}

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

done
