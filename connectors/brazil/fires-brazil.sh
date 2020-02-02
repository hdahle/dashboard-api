#!/bin/sh

# Fetch annual forest fire data from 
#   http://queimadas.dgi.inpe.br/queimadas/portal-static/csv_estatisticas/historico_pais_brasil.csv
# Convert CSV file to JSON
# Resulting CSV file should be saved to queimadas-brazil.csv
#
# H. Dahle

REDIS=$1

if [ "$REDIS" = "" ]
then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]
  then
    echo "Not found: ${REDIS}"
    exit
  fi
fi

REDISKEY="queimadas-brazil"
TMPDIR=$(mktemp -d)
CSVFILE="${TMPDIR}/${REDISKEY}.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
DATE=`date`

echo ${DATE}
echo "Converting Brazil forest-fire data from CSV to JSON"
echo "Downloading ${REDISKEY}.csv, using tmpdir ${TMPDIR}"
curl "http://queimadas.dgi.inpe.br/queimadas/portal-static/csv_estatisticas/historico_pais_brasil.csv" > ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
    wc -l ${CSVFILE}   
    grep 2020 ${CSVFILE} 
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

# CSV input:

# Ano,Janeiro,Fevereiro,Março,Abril,Maio,Junho,Julho,Agosto,Setembro,Outubro,Novembro,Dezembro,Total
# 1998,-,-,-,-,-,3551,8067,35551,41976,23499,6804,4448,123896
# 1999,1081,1284,667,717,1811,3632,8758,39492,36914,27017,8863,4376,134612

# JSON output:

# { 'link': 'http://queimadas.dgi.inpe.br/queimadas/portal-static/estatisticas_paises/',
#   'license': 'Unknown. Public data source',
#   'source': 'INPE INSTITUTO NACIONAL DE PESQUISAS ESPACIAIS, Brazil',
#   'reference': 'INPE. Database of burns. Available at: http://queimadas.dgi.inpe.br/queimadas/bdqueimadas',
#   'accessed': '<date of access>'
#   'data':
#   [
#     { 'country': , 'year':COL1, 'data': [COL2,COL3, ... ,COL13] }
#
#   ]
# }

# Turn it into a JSON blob

awk -v d="${DATE}" -v COUNTRY="Brazil" 'BEGIN {ORS=""
            FS=","
            print "{"
            print "\"source\":\"INPE Instituto Nacional de Pesquisas Espaciais, Brazil. Programa Queimadas, queimadas@inpe.br\", "
            print "\"link\":\"http://queimadas.dgi.inpe.br/queimadas/portal-static/estatisticas_paises\", "
            print "\"license\":\"Unknown, publicly available data\", "
            print "\"email\":\"queimadas@inpe.br\", "
            print "\"accessed\":\"" d "\", "
            print "\"data\": ["
            FIRSTRECORD = 1
     }

     # Skip comments
     /^#/  {next}
     
     # Translate from Portuguese
     $1~/M?ximo+*/ { $1="Maximum" }
     $1~/M?dia\*/  { $1="Average" }
     $1~/M?nimo\*/ { $1="Minimum" }

     # Skip the first line in this CSV
     /Ano/ {next}

     NF==14 && (($1 > 1970 && $1 < 2100) || $1=="Maximum" || $1=="Average" || $1=="Minimum") { 
           if (!FIRSTRECORD) printf ","
            FIRSTRECORD = 0
            printf "{\"country\":\"%s\",\"year\":\"%s\",\"data\":",COUNTRY,$1
            for (i=2; i<14; i++) if ($i == "-") $i = "null"
            printf "[%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s]}",$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
            next
     }

     END   {print "]}"}' < ${CSVFILE} > ${JSONFILE}

echo "Storing JSON to Redis, bytes:"
cat ${JSONFILE} | wc --bytes

echo "Saving JSON to Redis with key ${REDISKEY}"
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

echo "Retrieving key=${REDISKEY} from Redis, bytes:"
${REDIS} get ${REDISKEY} | wc --bytes