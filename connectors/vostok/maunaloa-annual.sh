#!/bin/sh

# Fetch MaunaLoa annual mean
# Convert to JSON, combine into single JSON blob
# Store to Redis
#
# H. Dahle

MAUNALOA="co2_annmean_mLo"
TMPDIR=$(mktemp -d)

echo "Get Maunaloa annual mean CO2 data, convert to JSON and save to Redis"

if [ -f "${MAUNALOA}.txt" ]; then
    echo "File ${MAUNALOA}.txt exists"
else
    echo "Fetching Mauna Loa annual mean data from ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_annmean_mlo.txt, saving to ${MAUNALOA}.txt"
    curl "ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_annmean_mlo.txt" > ${MAUNALOA}.txt
fi
wc -l ${MAUNALOA}.txt

#Maunaloa format (co2_annmean_mlo.txt)
# # CO2 expressed as a mole fraction in dry air, micromol/mol, abbreviated as ppm
# #
# # year     mean      unc
# 1959   315.97     0.12
# 1960   316.91     0.12
# 1961   317.64     0.12

#JSON output:
# { 'source': '',
#   'license': '',
#   'publisher': '',
#   'reference': '',
#   'data':
#   [
#     { 'year':Maunaloa-COL1, 'co2':Maunaloa-COL2  }
#   ]
# }

REDISKEY="maunaloa-annual-mean"

echo "Cleaning Mauna Loa data, writing to ${TMPDIR}/${REDISKEY}.txt"

awk '/^#/       {next}
     NF==3      {print $1 " " $2}' < ${MAUNALOA}.txt >> ${TMPDIR}/${REDISKEY}.txt

wc -l ${TMPDIR}/${REDISKEY}.txt

echo "Sort data by year then convert to JSON, writing to ${TMPDIR}/${REDISKEY}.json"

sort -n ${TMPDIR}/${REDISKEY}.txt | awk 'BEGIN {ORS=""
            print "{"
            print "\"source\":\"Dr. Pieter Tans, NOAA/ESRL (www.esrl.noaa.gov/gmd/ccgg/trends/) and Dr. Ralph Keeling, Scripps Institution of Oceanography (scrippsco2.ucsd.edu/)\", "
            print "\"link\":\"ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt\", "
            print "\"data\": ["
            FIRSTRECORD = 1
     }

     # Skip comments
     /^*/  {next}

     # Skip text
     /[A-Za-z]/ {next}

     NF==2 {if (!FIRSTRECORD) printf ","
            FIRSTRECORD = 0
            printf " {\"x\":%s,\"y\":%s}", $1, $2
     }

     END   {print "]}"}' > ${TMPDIR}/${REDISKEY}.json

# sanity check
echo "Saving JSON, number of bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# save JSON to Redis
echo "Saving to Redis, key ${REDISKEY}"
redis-cli -x SET ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# quick test
echo "Retrieving keu=${REDISKEY}, number of bytes:"
redis-cli get ${REDISKEY} | wc --bytes
