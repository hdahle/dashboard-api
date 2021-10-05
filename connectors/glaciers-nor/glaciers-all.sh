#!/bin/sh

# Read glacier data from API
# Combine into single object
# Write back to Redis
#
# H. Dahle


TMPDIR=$(mktemp -d)
JSONFILE="${TMPDIR}/glaciers"
REDISKEY="glaciers-nor-all"

echo "File:" $JSONFILE
echo "[" > ${JSONFILE}
for GLACIER in  'Styggedalsbreen' 'Bondhusbrea' 'Boyabreen' 'Buerbreen' 'Hellstugubreen' 'Storbreen' 'Stigaholtbreen' 'Briksdalsbreen' 'Rembesdalskaaka' 'Engabreen' 'Faabergstolsbreen' 'Nigardsbreen' 'Lodalsbreen'
do
  curl -S -s "http://api.dashboard.eco/glacier-length-nor-${GLACIER}" >> ${JSONFILE}
  if [ "$GLACIER" != "Lodalsbreen" ]; then
    echo "," >> ${JSONFILE}
  fi
done
echo "]" >> ${JSONFILE}

wc ${JSONFILE}



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

echo "Hint: read back from Redis and verify with: redis-cli get ${REDISKEY} | jq ."

