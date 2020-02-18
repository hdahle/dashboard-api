#!/bin/sh

# Global Mean Sea Levels since 1880
# The CSV file is available at ftp://ftp.csiro.au/legresy/gmsl_files/CSIRO_Recons_gmsl_yr_2015.csv
#
# H. Dahle 2020

REDISKEY="CSIRO_Recons_2015"
TMPDIR=$(mktemp -d)
CSVFILE="${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
echo "Global Sea Level. Converting from CSV to JSON"
echo "Using temporary directory ${TMPDIR}"

if [ ! -f "${CSVFILE}" ]; then
  echo -n "File not found: ${CSVFILE}, downloading: "
  curl -s -S "ftp://ftp.csiro.au/legresy/gmsl_files/CSIRO_Recons_gmsl_yr_2015.csv" > ${CSVFILE}
fi

if [ -f "${CSVFILE}" ]; then
  echo -n "Number of lines in CSV, ${CSVFILE}: "
  cat ${CSVFILE} | wc -l
else
  echo "File not found: ${CSVFILE}, aborting"
  exit
fi

# Input CSV Format
#==> CSIRO_Recons.csv <==
#"Time","GMSL (mm)","GMSL uncertainty (mm)"
#1880.5, -157.1,   24.2
#1881.5, -151.5,   24.2
#1882.5, -168.3,   23.0

# Convert from CSV to JSON
awk -v d="${DATE}" 'BEGIN {
            ORS="";
            FS=",";
            print "{"
            print "\"source\": \"Commonwealth Scientific and Industrial Research Organisation (CSIRO), Australia.Church, John; White, Neil (2016): Reconstructed Global Mean Sea Level for 1870 to 2001. v2. \", "
            print "\"link\": \"https://research.csiro.au/slrwavescoast/sea-level/measurements-and-data/sea-level-data/\", "
            print "\"attribution\": "
            print "\"Church, J.A. and N.J. White (2011), Sea-level rise from the late 19th to the early 21st century. Surveys in Geophysics, 32, 585-602, doi:10.1007/s10712-011-9119-1. This paper is published _Open Access_\", "
            print "\"info\": \"This file contains the monthly Global Mean Sea Level (GMSL) time series as shown on figure 2 of Church and White (2006). The sea level was reconstructed as described in Church et al (2004). \", "
            print "\"license\": "
            print "\"Creative Commons Attribution 4.0 International Licence\", "
            print "\"accessed\": \"" d "\", "
            print "\"legend\":\"x: year, y: annual GSML in mm, uncertainty: undertainty in mm\", "
            print "\"data\":["
            FIRST=1
     }
     
     NF!=3  {next}
     
     /Time/ {next}

     {      gsub(/ /, "", $0)
            if (!FIRST) print ", "
            FIRST=0
            print "{"
            print "\"x\":" substr($1,1,4) "," 
            print "\"y\":" $2 ", " 
            print "\"uncertainty\":"  $3 
            print "}"
     }
     END   {print "]}"}' < ${CSVFILE} > ${JSONFILE}

# Quick test
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
