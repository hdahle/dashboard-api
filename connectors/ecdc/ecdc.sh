#!/bin/sh
#
# ECDC Weekly Corona Update
#
# H.Dahle, 2020

TMPDIR=$(mktemp -d)
SOURCEDIR="https://opendata.ecdc.europa.eu/covid19/subnationalcaseweekly/xlsx/"
TMPFILE="${TMPDIR}/ecdc.tmp"
XLSXFILE="${TMPDIR}/ecdc.xlsx"
REDISKEY="ecdc-weekly"
FILENAME="subnational_weekly_data_"
NODEPATH=$1

if [ ! -f "$NODEPATH" ] ; then
  echo "Usage: $0 nodepath"
  echo "  nodepath - path to the node.bin executable, e.g. /usr/bin"
  exit
fi

echo "Trying ${SOURCEDIR}"
echo "Saving to ${TMPFILE}"
curl  -s "${SOURCEDIR}" --output ${TMPFILE}

if grep "DOCTYPE html" ${TMPFILE}  ; then 
  echo "No update from ECDC"
else
  mv ${TMPFILE} ${XLSXFILE}
  echo "XLSX file stored in ${XLSXFILE}"
  ${NODEPATH} ecdc.js --verbose --file ${XLSXFILE} --key ${REDISKEY}
fi
