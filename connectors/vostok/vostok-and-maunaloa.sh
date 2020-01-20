#!/bin/sh

# Fetch the Vostok Ice Core 400.000 year CO2 data
# Fetch MaunaLoa annual mean
# Convert to JSON, combine into single JSON blob
# Store to Redis
#
# H. Dahle

MAUNALOA="co2_annmean_mLo"
VOSTOK="vostok-icecore-co2"
TMPDIR=$(mktemp -d)

echo "Combine Vostok and Maunaloa CO2 Data, convert to JSON and save to Redis"

if [ -f "${MAUNALOA}.txt" ]; then
    echo "File ${MAUNALOA}.txt exists"
else
    echo "Fetching Mauna Loa annual mean data from ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_annmean_mlo.txt, saving to ${MAUNALOA}.txt"
    curl "ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_annmean_mlo.txt" > ${MAUNALOA}.txt
fi
wc -l ${MAUNALOA}.txt

if [ -f  "${VOSTOK}.txt" ]; then
    echo "File ${VOSTOK}.txt exists"
else
    echo "Fetching Vostok data from https://cdiac.ess-dive.lbl.gov/ftp/trends/co2/vostok.icecore.co2, save to ${VOSTOK}.txt"
    curl "https://cdiac.ess-dive.lbl.gov/ftp/trends/co2/vostok.icecore.co2" > ${VOSTOK}.txt
fi
wc -l ${VOSTOK}.txt

#Vostk format:
#Mean
#Age of   age of    CO2
#Depth  the ice  the air concentration
#(m)   (yr BP)  (yr BP)  (ppmv)
#
#149.1 5679 2342 284.7
#173.1 6828 3634 272.8
#177.4 7043 3833 268.1
#228.6 9523 6220 262.2

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
#     { 'year':Vostok-COL3, 'co2':Vostok-COL4  }
#     { 'year':Maunaloa-COL1, 'co2':Maunaloa-COL2  }
#   ]
# }

REDISKEY="vostok-and-maunaloa"

echo "Cleaning Vostok data. Note: The dates in the Vostok are "Years BP" which is years before 1950. Writing to ${TMPDIR}/${REDISKEY}.txt"

awk '/^*/       {next}
     /[A-Za-z]/ {next}
     NF==4      {print 1950-$3 " " $4}' < ${VOSTOK}.txt > ${TMPDIR}/${REDISKEY}.txt

echo "Cleaning Mauna Loa data, appending to ${TMPDIR}/${REDISKEY}.txt"

awk '/^#/       {next}
     NF==3      {print $1 " " $2}' < ${MAUNALOA}.txt >> ${TMPDIR}/${REDISKEY}.txt

wc -l ${TMPDIR}/${REDISKEY}.txt

echo "Sort data by year then convert to JSON, writing to ${TMPDIR}/${REDISKEY}.json"

sort -n ${TMPDIR}/${REDISKEY}.txt | awk 'BEGIN {ORS=""
            print "{"
            print "\"source\":\"(1) Barnola, J.-M., D. Raynaud, C. Lorius, and N.I. Barkov. 2003. Historical CO2 record from the Vostok ice core. In Trends: A Compendium of Data on Global Change. Carbon Dioxide Information Analysis Center, Oak Ridge National Laboratory, U.S. Department of Energy, Oak Ridge, and (2) Dr. Pieter Tans, NOAA/ESRL (www.esrl.noaa.gov/gmd/ccgg/trends/) and Dr. Ralph Keeling, Scripps Institution of Oceanography (scrippsco2.ucsd.edu/)\", "
            print "\"link\":\"https://cdiac.ess-dive.lbl.gov/trends/co2/ice_core_co2.html\", "
            print "\"ftp\":\"ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt\", "
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
