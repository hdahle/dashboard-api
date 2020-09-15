
#!/bin/sh

# Convert CSIRO CSV file to JSON and store into Redis
# CSIRO files: ftp://ftp.csiro.au/legresy/gmsl_files
#
# H. Dahle 2020

REDISKEY="CSIRO_Alt"
TMPDIR=$(mktemp -d)
CSVFILE="${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`

echo ${DATE}
echo "Global Sea Level. Converting from CSV to JSON"
echo "Using temporary directory ${TMPDIR}"

#if [ ! -f "${CSVFILE}" ]; then
#  echo -n "File not found: ${CSVFILE}, downloading: "
  curl -s -S "ftp://ftp.csiro.au/legresy/gmsl_files/CSIRO_Alt.csv" > ${CSVFILE}
#fi

if [ -f "${CSVFILE}" ]; then
    echo -n "Number of lines in CSV:"
    cat ${CSVFILE} | wc -l
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 
fi

# CSV format
#
# Time,GMSL (monthly),GMSL (smoothed)
# 1993.042,   -45.9,   #N/A
# 1993.125,   -47.9,   -44.5
# 1993.208,   -39.8,   -44.4
# 1993.292,   -45.5,   -41.9

awk -v d="${DATE}" 'BEGIN {
            ORS=""
            FS="[, \t]+"

            m["042"] = "01-15"; m["125"] = "02-15"; m["208"] = "03-15"
            m["292"] = "04-15"; m["375"] = "05-15"; m["458"] = "06-15"
            m["542"] = "07-15"; m["625"] = "08-15"; m["708"] = "09-15"
            m["792"] = "10-15"; m["875"] = "11-15"; m["958"] = "12-15"

            print "{"
            print "\"source\": \"Commonwealth Scientific and Industrial Research Organisation (CSIRO), Australia\", "
            print "\"link\": \"ftp://ftp.csiro.au/legresy/gmsl_files\", "
            print "\"info\": \"Global Mean Sea Levels in mm since 1993. \", "
            print "\"license\": "
            print "\"Creative Commons Attribution 4.0 International Licence\", "
            print "\"accessed\":\"" d "\", "
            print "\"info\":\"t: date, y: smoothed GSML\", "
            print "\"data\":["
            FIRST=1
     }

     NF!=3  {next}
     /Time/ {next}

     {      year = substr($1, 1, 4)
            month= substr($1, 6, 3)
            if (!FIRST) print ", "
            FIRST=0
            print "{\"t\":\"" year "-" m[month] "\",\"y\":" $2 "}"
     }
     END   {print "]}"}' < ${CSVFILE}  > ${JSONFILE}

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
