#!/bin/sh
#
# Convert CSV file to JSON
# Store JSON in Redis
#
# H. Dahle, 2021

REDIS=$1

if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]; then
    echo "Not found: ${REDIS}"
    exit
  fi
fi

REDISKEY="oecd-meat-2020" 

TMPDIR=$(mktemp -d)
CSVFILE="${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`
echo ${DATE}
echo "Converting OECD data from CSV to JSON"
echo "Using ${REDISKEY}.csv, using tmpdir ${TMPDIR}"
if [ -f "${CSVFILE}" ]; then
  LINES=`cat ${CSVFILE} | wc -l`
  if [ "$LINES" -eq "0" ]; then
    echo "Error: empty file, aborting"
    exit
  fi
else
  echo "File not found: ${CSVFILE}, aborting "
  exit 0
fi

cat ${CSVFILE} | sed s/\"//g  | awk -v ACCESSDATE="${DATE}" 'BEGIN {
        ORS = ""
        FS  = ","
        START = 0
        meatName["SHEEP"] = "Sheep"; 
        meatName["BEEF"] = "Beef";
        meatName["PIG"] = "Pork";
        meatName["POULTRY"] = "Poultry";
 }
 $1 == "SOURCE"  { SOURCE=$2 ; next }
 $1 == "LINK"    { LINK=$2 ; next }
 $1 == "LICENSE" { LICENSE=$2; next }
 $1 == "LOCATION" { START = 1; next }
 
 START && $4 == "KG_CAP" { data[$1][$3][$6] = $7 }  # data[country][type of meat][year] = kg per capita

 END {  print "{"
        print "\"source\":\"" SOURCE "\", "
        print "\"link\":\"" LINK "\", "
        print "\"license\":\"" LICENSE "\", "
        print "\"accessed\":\"" ACCESSDATE "\", "
        print "\"data\": ["

        firstcountry=1
        for (COUNTRY in data) {
          if (!firstcountry) print ","
          firstcountry=0
          printf "\n{\"country\":\"%s\",\"data\":[", COUNTRY
          firsttype=1

          n=split("SHEEP BEEF PIG POULTRY", meats, " "); # need to step thru array in specific sequence
          for (i=1; i<=n; i++) {         
            
            if (!firsttype) print ","
            firsttype=0 
            printf "{\"meat\":\"%s\",\"data\":[", meatName[meats[i]]
            first = 1
            for (YEAR in data[COUNTRY][meats[i]]) {
              if (!first) print ","
              first = 0
              printf "{\"x\":%d,\"y\":%s}",YEAR, data[COUNTRY][meats[i]][YEAR]
            }
            print "]}"
          }
          print "]}"
        }
        print "]}"
}' > ${JSONFILE}

echo -n "Storing JSON to Redis, bytes: "
cat ${JSONFILE} | wc --bytes 

echo -n "Saving JSON to Redis with key ${REDISKEY}, result: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

echo -n "Retrieving key=${REDISKEY} from Redis, bytes: "
${REDIS} get ${REDISKEY} | wc --bytes

