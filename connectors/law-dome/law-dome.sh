#!/bin/sh

# Convert Law Dome txt file to JSON and store into Redis
# ftp://ftp.ncdc.noaa.gov/pub/data/paleo/icecore/antarctica/law/law2018co2.txt
#
# H. Dahle

# Input TXT Format
# law2018co2.txt:
# # Data line format - tab-delimited text, variable short name as header
# # Missing Values:  
# #
# SampleID	age_ice	age_CO2	CO2ppm	CO2err
# DSSW20K 15.8	firn	1996	359.87	0.02
# DSSW20K 29	firn	1994	357.24	0.04
# DE08-2 0	firn	1993	354.6	0.02
# DSSW20K 37.8	firn	1992	353.89	0.04

REDISKEY="law2018co2"
TMPDIR=$(mktemp -d)

if [ -f "${REDISKEY}.txt" ]; then
    echo "Input file found, skipping download"
else
    echo "Input file not found: ${REDISKEY}.txt, downloading from ftp.ncdc.noaa.gov"
    curl "ftp://ftp.ncdc.noaa.gov/pub/data/paleo/icecore/antarctica/law/law2018co2.txt" > ${REDISKEY}.txt
    echo "Bytes downloaded:"
    wc --bytes ${REDISKEY}.txt
fi

# Convert TXT to JSON
awk 'BEGIN {ORS="";
            FS=" ";
            print "{"
            print "\"source\": \"Authors: Mauro Rubino, David Etheridge, David Thornton, Russell Howden, Colin Allison, Roger Francey, Ray Langenfelds, Paul Steele, Cathy Trudinger, Darren Spencer, Mark Curran, Tas Van Ommen, and Andrew Smith. Published:2018-12-14. Title: Revised records of atmospheric trace gases CO2, CH4, N2O and d13C-O2 over the last 2000 years from Law Dome, Antarctica\", "
            print "\"link\": \"ftp://ftp.ncdc.noaa.gov/pub/data/paleo/icecore/antarctica/law\", "
            print "\"info\": \"CO2 levels in PPM for the last 2000 years \", "
            print "\"data\": [{\"region\":\"global\", \"data\":["
            FIRST=1
     }

     # Skip comments etc
     NF!=6 {next}
     /^Sample/ {next}
     /^#/ {next}
     
     # Process single line of data
     {
            if (!FIRST) print ", "
            FIRST=0
            printf "{\"year\":\"%d\",\"data\":%.1f}", $4, $5
     }
     END   {print "]}]}"}' < ${REDISKEY}.txt  > ${TMPDIR}/${REDISKEY}.json

# Quick test
echo "Storing JSON, number of bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# stick it into Redis
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# Quick verification
echo "Retrieving JSON from Redis, bytes:"
redis-cli get ${REDISKEY} | wc --bytes
