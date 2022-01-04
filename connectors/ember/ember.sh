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

REDISKEYTOP15="top15windsolar-2020"
JSONFILETOP15="${REDISKEYTOP15}.json"

if [ -f ${JSONFILETOP15} ]; then
    echo -n "JSON-file found "
    cat ${JSONFILETOP15} | wc -l
    LINES=`cat ${JSONFILETOP15} | wc -l`
    if [ "$LINES" -eq "0" ]; then
      echo "Error: empty file, aborting"
      exit
    fi
else
    echo "File not found: ${JSONFILETOP15}, aborting "
    exit 0
fi
    
echo -n "Storing JSON to Redis, bytes: "
cat ${JSONFILETOP15} | wc --bytes

echo -n "Saving JSON to Redis with key ${REDISKEYTOP15}, result: "
${REDIS} -x set ${REDISKEYTOP15} < ${JSONFILETOP15}

echo -n "Retrieving key=${REDISKEYTOP15} from Redis, bytes: "
${REDIS} get ${REDISKEYTOP15} | wc --bytes



REDISKEYMIX="global-electricity-mix-2020"
TMPDIR=$(mktemp -d)
CSVFILE="${REDISKEYMIX}.csv"
JSONFILE="${TMPDIR}/${REDISKEYMIX}.json"
DATE=`date --iso-8601='minutes'`
echo ${DATE}
echo "Converting electricity mix data from CSV to JSON"

if [ -f "${CSVFILE}" ]; then
    echo -n "CSV-file found "
    cat ${CSVFILE} | wc -l
    LINES=`cat ${CSVFILE} | wc -l`
    if [ "$LINES" -eq "0" ]; then
      echo "Error: empty file, aborting"
      exit
    fi
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

awk -F "\t" 'BEGIN { START = 0 }

$1 == "Year" {
	for (i=1; i<=NF; i++) {
		label[i] = $i
	}
	next
}
$1 == "2000" { START = 1 }

START { 
	for (i=1;i<=NF;i++) {
		datasets[label[i]][$1] = $i 
	}
}

END {
    printf "{\"source\":\"Ember, Global Electricity Review 2021, March 2021\","
	printf "\"link\":\"https://ember-climate.org/data/global-electricity/\", "
	printf "\"info\":\"Global electricity generation mix\", "
	printf "\"data\": {"
	printf "\"yAxisLabel\":\"TWh\","
	printf "\"datasets\": ["

    printComma=0;
    for (i in datasets) {
		if (printComma++) printf ","
		printf "{\"label\":\"%s\",", i
        printf "\"data\":["
		printComma=0;
		for (j in datasets[i]) {
   		    if (printComma++) printf ","
			printf "{\"x\":\"%s\",\"y\":%s}", j, datasets[i][j]
		}
		printf "]}"
	}	
	print "]}}"

}' < ${CSVFILE} > ${JSONFILE}

echo -n "Storing JSON to Redis, bytes: "
cat ${JSONFILE} | wc --bytes

echo -n "Saving JSON to Redis with key ${REDISKEYMIX}, result: "
${REDIS} -x set ${REDISKEYMIX} < ${JSONFILE}

echo -n "Retrieving key=${REDISKEYMIX} from Redis, bytes: "
${REDIS} get ${REDISKEYMIX} | wc --bytes