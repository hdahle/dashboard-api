#!/bin/sh
#
# ECDC Weekly Corona Update
# This was originally written before ECDC supported CSV
#
# H.Dahle, 2020

TMPDIR=$(mktemp -d)

SOURCEDIR="https://opendata.ecdc.europa.eu/covid19/subnationalcaseweekly/csv/data.csv"
# SOURCEDIR="https://opendata.ecdc.europa.eu/covid19/subnationalcaseweekly/xlsx/"
TMPFILE="${TMPDIR}/ecdc.tmp"
CSVFILE="${TMPDIR}/ecdc.csv"
REDISKEY="ecdc-weekly"
NODEPATH=$1

if [ ! -f "$NODEPATH" ] ; then
  echo "Usage: $0 nodepath"
  echo "  nodepath - path to the node.bin executable, e.g. /usr/bin/node"
  exit
fi

echo "Trying ${SOURCEDIR}"
echo "Saving to ${TMPFILE}"
curl "${SOURCEDIR}" --output ${TMPFILE}

if grep "DOCTYPE html" ${TMPFILE}  ; then 
  echo "No update from ECDC"
else
  mv ${TMPFILE} ${CSVFILE}
  echo "CSV file stored in ${CSVFILE}"
  ${NODEPATH} ecdc-csv.js --file ${CSVFILE} --key ${REDISKEY}
fi
