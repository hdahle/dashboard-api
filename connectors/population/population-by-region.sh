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
#   data:
#     [
#       { region:$2, data:[1,2,3,4,5,...,0] },
#       { region:$2, data:[1,2,3,4,5,...,0] }
#     ]
# }
#
# Only contains REGIONS, all countries are skipped


INPUTFILE="WPP2019_TotalPopulationBySex.csv"
REDISKEY="WPP2019_TotalPopulationByRegion"
TMPDIR=$(mktemp -d)

# Fetch population data from UN
# curl "https://population.un.org/wpp/Download/Files/1_Indicators%20(Standard)/CSV_FILES/WPP2019_TotalPopulationBySex.csv" > ${INPUTFILE}

if [ -f "${INPUTFILE}" ]; then
    echo "Converting ${INPUTFILE} from CSV to JSON, using temp directory ${TMPDIR}"
else
    echo "File not found: ${INPUTFILE}, aborting"
    exit
fi

# Convert JSON to CSV

awk 'BEGIN {FS=",";
            ORS="";
            print "{"
            print "\"source\":"
            print "\"United Nations World Population Prospects 2019\", "
            print "\"link\":"
            print "\"https://population.un.org/wpp/Download/Standard/CSV\", "
            print "\"license\":"
            print "\"Creative Commons license CC BY 3.0 IGO: http://creativecommons.org/licenses/by/3.0/igo/\", "
            print "\"info\":"
            print "\"Population data is in millions\", "
            print "\"data\": ["
            FIRSTREGION=1
            REGION=""
     }

     $1=="LocID" {next}

     $4!="Medium" {next}

     $1!="900" && $1!="903" && $1!="904" && $1!="905" && $1!="908" && $1!="909" && $1!="935" {next}

     # Start new REGION
     REGION!=$1 {
            if (!FIRSTREGION) printf "]},"
            printf "{\"region\":\"%s\",\"data\":[", $2
            REGION=$1
            FIRSTYEAR=1
     }

     # Continue with a REGION
     REGION==$1 {
            if (!FIRSTYEAR) printf ", "
            FIRSTYEAR=0
            FIRSTREGION=0
            printf "{\"t\":%d,\"y\":%d}", $5, $9/1000
     }
     END   {print "]}]}"}' < ${INPUTFILE}  > ${TMPDIR}/${REDISKEY}.json

echo "JSON result in bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

# stick it into Redis
echo "Storing to key=${REDISKEY} in Redis"
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

# sanity check
echo "Retrieving key=${REDISKEY}, number of bytes:"
redis-cli get ${REDISKEY} | wc --bytes
