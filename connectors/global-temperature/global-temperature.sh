#!/bin/sh

# Convert nasa.gov GISTEMP v4 CSV-file to JSON and store into Redis
# https://data.giss.nasa.gov/gistemp/graphs_v4/graph_data/Global_Mean_Estimates_based_on_Land_and_Ocean_Data/graph.csv
# The CSV file is updated middle of every month
#
# H. Dahle

REDIS=$1
if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]; then
    echo "Not found: ${REDIS}"
    exit
  fi
fi

REDISKEY="global-temperature-anomaly"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date`

echo ${DATE}
echo "Downloading from data.giss.nasa.gov"
curl "https://data.giss.nasa.gov/gistemp/graphs_v4/graph_data/Global_Mean_Estimates_based_on_Land_and_Ocean_Data/graph.csv" > ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
  echo -n "Bytes downloaded (CSV size):"
  cat ${CSVFILE} | wc --bytes 
else
  echo "Download failed, aborting"
  exit 0
fi

# Input CSV format
#
# "Land-Ocean Temperature Index (C)
# --------------------------------"
# Year,No_Smoothing,Lowess(5)
# 1880,-0.16,-0.08
# 1881,-0.07,-0.12

# Convert CSV to JSON
awk -v d="${DATE}" 'BEGIN {ORS="";
            FS=",";
            print "{"
            printf "\"source\": \"GISTEMP Team, 2020: GISS Surface Temperature Analysis (GISTEMP), version 4. NASA Goddard Institute for Space Studies. Dataset accessed on %s at https://data.giss.nasa.gov/gistemp/.  Lenssen, N., G. Schmidt, J. Hansen, M. Menne, A. Persin, R. Ruedy, and D. Zyss, 2019: Improvements in the GISTEMP uncertainty model. J. Geophys. Res. Atmos., 124, no. 12, 6307-6326, doi:10.1029/2018JD029522.\", ", date
            print "\"link\": \"https://data.giss.nasa.gov/gistemp/graphs_v4/\", "
            print "\"info\": \"Land-ocean temperature index, 1880 to present, with base period 1951-1980\", "
            print "\"accessed\": \"" d "\", "
            print "\"data\": ["
            FIRST=1
     }

     # Skip comments etc
     NF!=3 {next}
     /Year/ {next}
     
     # Process single line of data
     {
            if (!FIRST) print ", "
            FIRST=0
            printf "{\"year\":%d,\"mean\":%s, \"smooth\":%s }", $1, $2, $3
     }
     END   {print "]}"}' < ${CSVFILE}  > ${JSONFILE}

# Quick test
echo -n "Storing (JSON size):"
cat ${JSONFILE} | wc --bytes 

# stick it into Redis
echo -n "Storing to Redis, key=${REDISKEY}, result: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

# Quick verification
echo -n "Retrieving from Redis, bytes:"
${REDIS} get ${REDISKEY} | wc --bytes
