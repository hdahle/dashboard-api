#!/bin/sh

KEY="oxfam-2020"
FILE="${KEY}.json"

if [ ! -f ${FILE} ] ; then
  echo File not found: ${FILE}
  exit 1
fi

echo Redis-key: ${KEY}
echo Reading from file: ${FILE}

redis-cli -x set ${KEY} < ${FILE}

