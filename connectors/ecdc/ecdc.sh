#!/bin/sh

SOURCEDIR="https://www.ecdc.europa.eu/sites/default/files/documents"
FILENAME="subnational_weekly_data_2020-10-01.xlsx"
OUTPUTFILE="ecdc.xlsx"

curl  "${SOURCEDIR}/${FILENAME}" --output ${OUTPUTFILE}


