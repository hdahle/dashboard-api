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

REDISKEY="poore-nemecek-2018" 

TMPDIR=$(mktemp -d)
CSVFILE="${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date --iso-8601='minutes'`
#echo ${DATE}
#echo "Converting OECD data from CSV to JSON"
#echo "Using ${REDISKEY}.csv, using tmpdir ${TMPDIR}"
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

cat ${CSVFILE}  | awk -v ACCESSDATE="${DATE}" 'BEGIN {
        ORS = ""
        FS  = ","
        LINES = 0       
 }
 
 $1 == "Food product" { 
   for (i=2; i<=NF; i++) datasetNames[i] = $i
   next
 }
 
NF == 9 {
  total = 0
  for (i=2; i<=NF; i++) {
    total += $i
  }
  totals[LINES] = total
}

 NF == 9 { 
        labels[LINES] = $1
        for (i=2; i<NF; i++) datasets[i][LINES] = $i
        LINES++
 } 

 END {  print "{"
        print "\"source\":\"Reducing food’s environmental impacts through producers and consumers, BY J. POORE, T. NEMECEK, SCIENCE01 JUN 2018 : 987-992 https://science.sciencemag.org/content/360/6392/987\", "
        print "\"link\":\"https://ourworldindata.org/food-choice-vs-eating-local\", "
        print "\"accessed\":\"" ACCESSDATE "\", "
        print "\"data\": {"
  
        print "\n\"labels\": ["
        printComma = 0
        for (i in labels) {
          if (printComma++) print ","
          print "\"" labels[i] "\""
        }
        print "],"
  
        print "\n\"totals\": ["
        printComma = 0
        for (i in totals) {
          if (printComma++) print ","
          print "\"" totals[i] "\""
        }
        print "],"
  
        print "\"datasets\": [\n"
        
        printComma = 0
        for (i in datasets) {
          if (printComma) print ","
          print "{\"label\":\"" datasetNames[i] "\","
          print "\"data\":["
          printComma = 0
          for (x in datasets[i]) {
            if (printComma++) print ","
            print datasets[i][x]
          }
          print "]}\n"
        }
        print "]}}\n"
}' #> ${JSONFILE}
exit
echo -n "Storing JSON to Redis, bytes: "
cat ${JSONFILE} | wc --bytes 

echo -n "Saving JSON to Redis with key ${REDISKEY}, result: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

echo -n "Retrieving key=${REDISKEY} from Redis, bytes: "
${REDIS} get ${REDISKEY} | wc --bytes

