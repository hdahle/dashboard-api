#!/bin/sh


# Convert CSV file to JSON
# Resulting CSV file should be saved to queimadas-brazil.csv
#
# H. Dahle

REDIS=$1

if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]; then
    echo "Not found: ${REDIS}"
    exit
  fi
fi

REDISKEY="covid-timeseries-country"
TMPDIR=$(mktemp -d)
CSVFILE="time_series_19-covid-Confirmed.csv"
JSONFILE="${TMPDIR}/${REDISKEY}.json"
#JSONFILE="${REDISKEY}.json"
DATE=`date`

echo ${DATE}
echo "Converting Covid data from CSV to JSON"
#echo "Downloading ${REDISKEY}.csv, using tmpdir ${TMPDIR}"
#curl --silent --show-error "http://queimadas.dgi.inpe.br/queimadas/portal-static/csv_estatisticas/historico_pais_brasil.csv" > ${CSVFILE}

if [ -f "${CSVFILE}" ]; then
    echo -n "Downloaded CSV-file, lines: "
    cat ${CSVFILE} | wc -l    
    LINES=`cat ${CSVFILE} | wc -l`
#    if [ "$LINES" -eq "0" ]; then
#      echo "Error: nothing downloaded, aborting"
#      exit
#    fi
    # grep 2020 ${CSVFILE} 
else
    echo "File not found: ${CSVFILE}, aborting "
    exit 0
fi

# CSV input:

#Province/State,Country/Region,Lat,Long,1/22/20,1/23/20,1/24/20,1/25/20,1/26/20,1/27/20,1/28/20,1/29/20,1/30/20,1/31/20,2/1/20,2/2/20,2/3/20,2/4/20,2/5/20,2/6/20,2/7/20,2/8/20,2/9/20,2/10/20,2/11/20,2/12/20,2/13/20,2/14/20,2/15/20,2/16/20,2/17/20,2/18/20,2/19/20,2/20/20,2/21/20,2/22/20,2/23/20,2/24/20,2/25/20,2/26/20,2/27/20,2/28/20,2/29/20,3/1/20,3/2/20,3/3/20,3/4/20,3/5/20
#Anhui,Mainland China,31.8257,117.2264,1,9,15,39,60,70,106,152,200,237,297,340,408,480,530,591,665,733,779,830,860,889,910,934,950,962,973,982,986,987,988,989,989,989,989,989,989,990,990,990,990,990,990,990
#Beijing,Mainland China,40.1824,116.4142,14,22,36,41,68,80,91,111,114,139,168,191,212,228,253,274,297,315,326,337,342,352,366,372,375,380,381,387,393,395,396,399,399,399,400,400,410,410,411,413,414,414,418,418
#Chongqing,Mainland China,30.0572,107.874,6,9,27,57,75,110,132,147,182,211,247,300,337,366,389,411,426,428,468,486,505,518,529,537,544,551,553,555,560,567,572,573,575,576,576,576,576,576,576,576,576,576,576,576

# Turn it into a JSON blob

gawk -v d="${DATE}" 'BEGIN {ORS=""
            FS=","
            print "{"
            print "\"source\":\"2019 Novel Coronavirus COVID-19 (2019-nCoV) Data Repository by Johns Hopkins CSSE, https://systems.jhu.edu/\", "
            print "\"link\":\"https://github.com/CSSEGISandData/COVID-19\", "
            print "\"license\":\"README.md in the Github repo says: This GitHub repo and its contents herein, including all data, mapping, and analysis, copyright 2020 Johns Hopkins University, all rights reserved, is provided to the public strictly for educational and academic research purposes. The Website relies upon publicly available data from multiple sources, that do not always agree. The Johns Hopkins University hereby disclaims any and all representations and warranties with respect to the Website, including accuracy, fitness for use, and merchantability. Reliance on the Website for medical guidance or use of the Website in commerce is strictly prohibited\", "
            print "\"accessed\":\"" d "\", "
            print "\"data\": ["
            FIRSTRECORD = 1
            START = 0
            m[1] = "Jan"; m[2] = "Feb"; m[3] = "Mar"; m[4] = "Apr";
            m[5] = "May"; m[6] = "Jun"; m[7] = "Jul"; m[8] = "Aug";
            m[9] = "Sep"; m[10] = "Oct"; m[11] = "Nov"; m[12] = "Dec";
     }

     # Skip comments
     /^#/  {next}

     # Sometimes dataset has a missing last datum
     $NF == "" {  $NF = $(NF-1) }

     # This line contains the list of dates, from $5 to $NF
     # Save the list of dates in the dates[] array
     $1=="Province/State" { 
            NUMF = NF
            
            for (i=5; i<=NF; i++) {
              split($i, date, "/")
              if (date[1] > 13 || date[1]<1 ) {
                print "Error in date: " $0
                exit
              }
              # Date conversion: "1/31/20" => "2020-Jan-31"
              dates[i] = "20"  date[3] "-" m[date[1]] "-" date[2]
            }
            next
     }

     {      indexOfDate = 5
            # In some cases, $1 = "Region, State",,...
            # The comma in Region,State causes NF to be to be off-by-one
            country = $2
            if (NUMF != NF) {
              country = $3
              indexOfDate = 6
            }

            # Some countries are reported by region. Region is $1, Country is $2
            # We only care about Country
            # So we have to add all the regions in a Country
            # An associative array seems a good approach
            for (i=indexOfDate; i<=NF; i++) {
              data[country][i-indexOfDate+5] += $i
            }
     }

     END   {
       firstcountry = 1
       for (country in data) {
         if (!firstcountry) print ",\n"
         firstcountry = 0
         print "{\"country\":\"" country "\",\"data\":["
         first = 1;
         for (j in data[country]) {
           if (!first) print ","
           print "{\"date\":\"" dates[j] "\",\"cases\":" data[country][j] "}"
           first = 0
         }
         print "]}"
       }       
       print " ]}"}' < ${CSVFILE} > ${JSONFILE}

echo -n "Storing JSON to Redis, bytes: "
cat ${JSONFILE} | wc --bytes 

echo -n "Saving JSON to Redis with key ${REDISKEY}, result: "
${REDIS} -x set ${REDISKEY} < ${JSONFILE}

echo -n "Retrieving key=${REDISKEY} from Redis, bytes: "
${REDIS} get ${REDISKEY} | wc --bytes
