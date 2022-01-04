#!/bin/sh
#
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

REDISKEY="emissions-per-capita-by-income-2020"
JSONFILE="${REDISKEY}.json"

if [ -f ${JSONFILE} ]; then
    echo -n "JSON-file found "
    cat ${JSONFILE} | wc -l
    LINES=`cat ${JSONFILE} | wc -l`
    if [ "$LINES" -eq "0" ]; then
      echo "Error: empty file, aborting"
      exit
    fi
else
    echo "File not found: ${JSONFILE}, aborting "
    exit 0
fi
    
echo -n "Storing JSON to Redis, bytes: "
cat ${JSONFILE} | wc --bytes

echo -n "Saving JSON to Redis with key ${REDISKEY}, result: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

echo -n "Retrieving key=${REDISKEY} from Redis, bytes: "
${REDIS} get ${REDISKEY} | wc --bytes


