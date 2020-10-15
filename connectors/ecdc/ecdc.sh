#!/bin/sh
#
# ECDC Weekly Corona Update
#
# H.Dahle, 2020

TMPDIR=$(mktemp -d)
SOURCEDIR="https://www.ecdc.europa.eu/sites/default/files/documents"
TMPFILE="${TMPDIR}/ecdc.tmp"
XLSXFILE="${TMPDIR}/ecdc.xlsx"
REDISKEY="ecdc-weekly"
FILENAME="subnational_weekly_data_"
NODEPATH=$1

if [ "$NODEPATH" = "" ] ; then
  echo "Usage: $0 nodepath"
  echo "  nodepath - path to the node.bin executable, e.g. /usr/bin"
  exit
fi

DATETWODAYSAGO=`date -I -d "2 days ago"`
DATEYESTERDAY=`date -I -d yesterday`
DATETODAY=`date -I -d today`

for DSTRING in $DATETWODAYSAGO $DATEYESTERDAY $DATETODAY
do  
  if [ ${DSTRING} = "2020-10-15" ] ; then
    echo "Trying ${SOURCEDIR}/${FILENAME}${DSTRING}_0.xlsx"
    echo "Saving to ${TMPFILE}"
    curl  -s "${SOURCEDIR}/${FILENAME}${DSTRING}_0.xlsx" --output ${TMPFILE}
  else
    echo "Trying ${SOURCEDIR}/${FILENAME}${DSTRING}_0.xlsx"
    echo "Saving to ${TMPFILE}"
    curl  -s "${SOURCEDIR}/${FILENAME}${DSTRING}_0.xlsx" --output ${TMPFILE}
  fi

  if grep "DOCTYPE html" ${TMPFILE}  ; then 
    echo "No update from ECDC for date ${DSTRING}"
  else
    mv ${TMPFILE} ${XLSXFILE}
    echo "XLSX file stored in ${XLSXFILE}"
    ${NODEPATH}/node ecdc.js --verbose --file ${XLSXFILE} --key ${REDISKEY}
  fi
done