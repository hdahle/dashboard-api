#!/bin/sh

# UN Population Statistocs
# Download CSV file
# Convert CSV to JSON
# Store JSON in Redis
#
# H. Dahle

# Input CSV FOrmat
# LocID,Location,VarID,Variant,Time,MidPeriod,PopMale,PopFemale,PopTotal
# 4,Afghanistan,2,Medium,1950,1950.5,4099.243,3652.874,7752.117
# 4,Afghanistan,2,Medium,1951,1951.5,4134.756,3705.395,7840.151

# Output JSON
#
# {
#   source:..., license:..., attribution:...,
#   data: {
#       datasets: [
#              {
#                label:
#                data: []
#             }
#      ]
#}
# }
#
# Only contains REGIONS, all countries are skipped

INPUTFILE="WPP2019_TotalPopulationBySex.csv"
REDISKEY="population-by-region"
TMPDIR=$(mktemp -d)
URL="https://population.un.org/wpp/Download/Files/1_Indicators%20(Standard)/CSV_FILES/WPP2019_TotalPopulationBySex.csv"

if [ -f "${INPUTFILE}" ]; then
    echo "Converting ${INPUTFILE} from CSV to JSON, using temp directory ${TMPDIR}"
else
    echo "File not found: ${INPUTFILE}, downloading from UN"
    # Fetch population data from UN
    curl ${URL} > ${INPUTFILE}
    wc -l ${INPUTFILE}
fi

# Convert JSON to CSV

awk -v URL=${URL} 'BEGIN { FS=","; ORS="" }

     $4 != "Medium" {next}
     
     # UN codes for the regions of the world, we skip all individual countries
     $1=="900" || $1=="903" || $1=="904" || $1=="905" || $1=="908" || $1=="909" || $1=="935" { 
       if ($1 == 905) $2 = "N America";
       if ($1 == 904) $2 = "S America";
       population[$2][$5] = $9
       next      
     }

     END   {
       print "{"
       print "\"source\":\"United Nations World Population Prospects 2019\", "
       print "\"link\":\"" URL "\", " 
       print "\"license\":\"Creative Commons license CC BY 3.0 IGO: http://creativecommons.org/licenses/by/3.0/igo/\", "
       print "\"info\":\"Population data is in millions\", "
       print "\"data\":{"
       print "\"datasets\":["
       printComma = 0;
       for (region in population) {
         if (printComma++) print ","
         print "{\"label\":\"" region "\","
         print "\"data\":["
         printComma = 0
         for (year in population[region]) {
           if (printComma++) print ","
           printf "{\"x\":%d, \"y\":%d}",year,population[region][year] / 1000
         }
         print "]}"
       }
       print "]}}\n"
     }' < ${INPUTFILE}  > ${TMPDIR}/${REDISKEY}.json

echo "JSON result in bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# When installing cron job, provde fully qualified filename to this script
# Cron doesnt run with the same PATH as regular user
REDIS=$1
if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
fi

if [ ! `which ${REDIS}` ]; then
  echo "Redis-executable not found: ${REDIS}"
  echo "Saving to ${REDISKEY}.json"
  cp ${TMPDIR}/${REDISKEY}.json ${REDISKEY}.json
else
  # stick it into Redis
  echo "Storing to key=${REDISKEY} in Redis"
  redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json
  # sanity check
  echo "Retrieving key=${REDISKEY}, number of bytes:"
  redis-cli get ${REDISKEY} | wc --bytes
fi