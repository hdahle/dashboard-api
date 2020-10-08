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

DATETWODAYSAGO=`date -I -d "2 days ago"`
DATEYESTERDAY=`date -I -d yesterday`
DATETODAY=`date -I -d today`

for DSTRING in $DATETWODAYSAGO $DATEYESTERDAY $DATETODAY
do  
  echo "Trying ${SOURCEDIR}/${FILENAME}${DSTRING}.xlsx"
  echo "Saving to ${OUTPUTFILE}"
  curl  "${SOURCEDIR}/${FILENAME}${DSTRING}.xlsx" --output ${TMPFILE}

  if grep "DOCTYPE html" ${TMPFILE}  ; then 
    echo No update from ECDC
  else
    mv ${TMPFILE} ${XLSXFILE}
    echo "XLSX file stored in ${XLSXFILE}"
    node ecdc.js --verbose --file ${XLSXFILE} --key ${REDISKEY}
  fi
done