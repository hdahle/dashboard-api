#!/bin/sh

# Fetch annual forest fire data from 
#   http://queimadas.dgi.inpe.br/queimadas/portal-static/csv_estatisticas/historico_pais_brasil.csv
# Convert CSV file to JSON
# Resulting CSV file should be saved to queimadas-brazil.csv
#
# H. Dahle

REDISKEY="queimadas-brazil"
TMPDIR=$(mktemp -d)

echo "Converting Brazil forest-fire data from CSV to JSON"
echo "Downloading ${REDISKEY}.csv, using tmpdir ${TMPDIR}"
curl "http://queimadas.dgi.inpe.br/queimadas/portal-static/csv_estatisticas/historico_pais_brasil.csv" > ${REDISKEY}.csv

if [ -f "${REDISKEY}.csv" ]; then
    wc -l ${REDISKEY}.csv    
else
    echo "File not found: ${REDISKEY}.csv, aborting "
    exit
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
#   'data':
#   [
#     { 'country': , 'year':COL1, 'data': [COL2,COL3, ... ,COL13] }
#
#   ]
# }

# Turn it into a JSON blob

awk  -v COUNTRY="brazil" 'BEGIN {ORS=""
            FS=","
            print "{"
            print "\"source\":\"INPE Instituto Nacional de Pesquisas Espaciais, Brazil. Programa Queimadas, queimadas@inpe.br\", "
            print "\"link\":\"http://queimadas.dgi.inpe.br/queimadas/portal-static/estatisticas_paises\", "
            print "\"license\":\"Unknown, publicly available data\", "
            print "\"email\":\"queimadas@inpe.br\", "
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

     {      if (!FIRSTRECORD) printf ","
            FIRSTRECORD = 0
            printf "{\"country\":\"%s\",\"year\":\"%s\",\"data\":",COUNTRY,$1
            for (i=2; i<14; i++) if ($i == "-") $i = "null"
            printf "[%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s]}",$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
            next
     }

     END   {print "]}"}' < ${REDISKEY}.csv > ${TMPDIR}/${REDISKEY}.json

echo "Storing JSON to Redis, bytes:"
cat ${TMPDIR}/${REDISKEY}.json | wc --bytes

echo "Saving JSON to Redis with key ${REDISKEY}"
redis-cli -x set ${REDISKEY} < ${TMPDIR}/${REDISKEY}.json

echo "Retrieving key=${REDISKEY} from Redis, bytes:"
redis-cli get ${REDISKEY} | wc --bytes
