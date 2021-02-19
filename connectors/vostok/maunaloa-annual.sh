#!/bin/sh

# Fetch MaunaLoa annual mean
# Convert to JSON, combine into single JSON blob
# Store to Redis
#
# H. Dahle

REDISKEY="maunaloa-annual-mean"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
echo "Fetching Mauna Loa annual mean data from ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_annmean_mlo.txt, saving to ${CSVFILE}"
curl "ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_annmean_mlo.txt" > ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

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

echo "Converting data to JSON, saving to ${JSONFILE}"
awk -v d="${DATE}" 'BEGIN {ORS=""
            print "{"
            print "\"source\":\"Dr. Pieter Tans, NOAA/ESRL (www.esrl.noaa.gov/gmd/ccgg/trends/) and Dr. Ralph Keeling, Scripps Institution of Oceanography (scrippsco2.ucsd.edu/)\", "
            print "\"link\":\"ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt\", "
            print "\"accessed\":\"" d "\", "
            print "\"data\": ["
            FIRSTRECORD = 1
     }

     # Skip comments
     /^#/  {next}

     NF==3 {if (!FIRSTRECORD) printf ","
            FIRSTRECORD = 0
            printf " {\"x\":%s,\"y\":%s}", $1, $2
     }

     END   {print "]}"}' < ${CSVFILE} > ${JSONFILE}

# Just for reassurance
echo -n "JSON byte count:"
cat ${JSONFILE} | wc --bytes

# When installing cron job, provde fully qualified filename to this script
REDIS=$1
if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]; then
    echo "Redis-executable not found: ${REDIS}, not storing in Redis"
    exit
  fi
fi

# Save to redis
echo -n "Saving JSON to Redis, key: ${REDISKEY}: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

# Quick verification
echo -n "Retrieving from Redis, JSON byte count: "
${REDIS} get ${REDISKEY} | wc --bytes
