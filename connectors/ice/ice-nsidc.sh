#!/bin/sh
# Fetch monthly ice extent data from colorado.edu
# There are twelve files per hemisphere, one per month
# Northern hemisphere

key="ice-nsidc"
tmpdir="/tmp/"
echo "Fetch ice-extent data from NSIDC, convert to JSON, store to Redis"
echo "Storing temporary files in ${tmpdir}"
echo "Starting FTP from colorado.edu "

curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_01_extent_v3.0.csv > ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_02_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_03_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_04_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_05_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_06_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_07_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_08_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_09_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_10_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_11_extent_v3.0.csv >> ${tmpdir}${key}.csv
curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data/N_12_extent_v3.0.csv >> ${tmpdir}${key}.csv

wc -l ${tmpdir}${key}.csv

echo "Starting data processing"

# Southern hemisphere
# curl ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/south/monthly/data/S_01_extent_v3.0.csv
# CSV input:
# year, mo,    data-type, region, extent,   area
# 1978, 12,      Goddard,      N,  13.67,  10.90
# 1979, 12,      Goddard,      N,  13.34,  10.63
# 1980, 12,      Goddard,      N,  13.59,  10.78
# 1981, 12,      Goddard,      N,  13.34,  10.54
# 1982, 12,      Goddard,      N,  13.64,  10.88

# JSON output:
# { 'source': '',
#   'license': '',
#   'publisher':'',
#   'data':
#   [
#     { 'region': COL4, 'type': COL3, 'data': [ {'year': COL1, 'extent': COL5, 'area':COL6 }, {...} ],
#     { 'region': COL4, 'type': COL3, 'data': [ {'year': COL3, 'extent': COL5, 'area':COL6 }, {...} ],
#     { ... }
#   ]
# }


# Turn it into a JSON blob

awk 'BEGIN {ORS=""
            FS=","
            COUNTRY=""
            print "{"
            print "\"source\":\"NSIDC National Snow and Ice Data Center, University of Colorado, Boulder. https://nsidc.org \", "
            print "\"link\":\"ftp://sidads.colorado.edu/DATASETS/NOAA/G02135/north/monthly/data\", "
            print "\"info\":\" \", "
            print "\"license\":\" \", "
            print "\"data\": ["
            FIRSTRECORD=1
     }

     # Skip any comments

     /^#/  { next }

     # Skip the CSV header line

     /year/{ next }

     # Trim off leading whitespace

           { gsub(/^[ \t]+/,"",$3) }
           { gsub(/^[ \t]+/,"",$4) }
           { gsub(/^[ \t]+/,"",$5) }
           { gsub(/^[ \t]+/,"",$6) }

     # Change the -9999 indicator to null

     $3~/\-9999/ { $5="null" }
     $5~/\-9999/ { $5="null" }
     $6~/\-9999/ { $6="null" }

           { if (FIRSTRECORD == 0) print ","
             printf "{\"year\":%d,\"month\":%d,\"type\":\"%s\",", $1,$2,$3
             printf "\"region\":\"%s\",\"extent\":%s,\"area\":%s}", $4,$5,$6
             FIRSTRECORD = 0
           }

     END   { print "]}" }' < ${tmpdir}${key}.csv > ${tmpdir}${key}.json

# stick it into Redis

echo "Updating Redis-database with key=${key}"

redis-cli -x set $key < ${tmpdir}${key}.json
