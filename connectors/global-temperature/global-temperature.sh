#!/bin/sh

# Convert nasa.gov GISTEMP v4 CSV-file to JSON and store into Redis
# https://data.giss.nasa.gov/gistemp/graphs_v4/graph_data/Global_Mean_Estimates_based_on_Land_and_Ocean_Data/graph.csv
# The CSV file is updated middle of every month
#
# H. Dahle

REDISKEY="global-temperature-anomaly"
TMPDIR=$(mktemp -d)

if [ -f "${REDISKEY}.csv" ]; then
    echo "Input file found, skipping download"
else
    echo "Input file not found: ${REDISKEY}.csv, downloading from data.giss.nasa.gov"
    curl "https://data.giss.nasa.gov/gistemp/graphs_v4/graph_data/Global_Mean_Estimates_based_on_Land_and_Ocean_Data/graph.csv" > ${REDISKEY}.csv
    echo "Bytes downloaded:"
    wc --bytes ${REDISKEY}.csv
fi

NOW=`date`

# Input CSV format
#
# "Land-Ocean Temperature Index (C)
# --------------------------------"
# Year,No_Smoothing,Lowess(5)
# 1880,-0.16,-0.08
# 1881,-0.07,-0.12

# Convert CSV to JSON
awk -v date="${NOW}" 'BEGIN {ORS="";
            FS=",";
            print "{"
            printf "\"source\": \"GISTEMP Team, 2020: GISS Surface Temperature Analysis (GISTEMP), version 4. NASA Goddard Institute for Space Studies. Dataset accessed on %s at https://data.giss.nasa.gov/gistemp/.  Lenssen, N., G. Schmidt, J. Hansen, M. Menne, A. Persin, R. Ruedy, and D. Zyss, 2019: Improvements in the GISTEMP uncertainty model. J. Geophys. Res. Atmos., 124, no. 12, 6307-6326, doi:10.1029/2018JD029522.\", ", date
            print "\"link\": \"https://data.giss.nasa.gov/gistemp/graphs_v4/\", "
            print "\"info\": \"Land-ocean temperature index, 1880 to present, with base period 1951-1980\", "
            print "\"date\": \"", date, "\", "
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
     END   {print "]}"}' < ${REDISKEY}.csv  > ${TMPDIR}/${REDISKEY}.json

# Quick test
echo "Storing JSON, number of bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# stick it into Redis
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# Quick verification
echo "Retrieving JSON from Redis, bytes:"
redis-cli get ${REDISKEY} | wc --bytes
