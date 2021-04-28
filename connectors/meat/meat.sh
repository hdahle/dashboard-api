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
        SOURCE = "OECD-FAO Agricultural Outlook (Edition 2020), https://data.oecd.org/agroutput/meat-consumption.htm"
        LINK="https://stats.oecd.org/sdmx-json/data/DP_LIVE/.MEATCONSUMP.../OECD?contentType=csv&detail=code&separator=comma&csv-lang=en"
        LICENSE="Except where additional restrictions apply as stated above, You can extract from, download, copy, adapt, print, distribute, share and embed Data for any purpose, even for commercial use. You must give appropriate credit to the OECD by using the citation associated with the relevant Data, or, if no specific citation is available, You must cite the source information using the following format: OECD (year), (dataset name),(data source) DOI or URL (accessed on (date)). When sharing or licensing work created using the Data, You agree to include the same acknowledgment requirement in any sub-licenses that You grant, along with the requirement that any further sub-licensees do the same."
        INFO="Consumption is reported in KG retail weight - ready to cook (production is reported in carcass weight)"
 }
 $1 == "SOURCE"   { SOURCE=$2 ; next }
 $1 == "LINK"     { LINK=$2 ; next }
 $1 == "INFO"     { INFO=$2; next }
 $1 == "LOCATION" { START = 1; next }
 
 # Country codes from https://irows.ucr.edu/research/tsmstudy/wbcountrycodes.htm

 $1 == "NOR" { $1 = "Norway" }
 $1 == "VNM" { $1 = "Vietnam" }
 $1 == "PHL" { $1 = "Philippines" }
 $1 == "EGY" { $1 = "Egypt" }
 $1 == "GBR" { $1 = "United Kingdom" }
 $1 == "IND" { $1 = "India" }
 $1 == "IDN" { $1 = "Indonesia" }
 $1 == "ARG" { $1 = "Argentina" }
 $1 == "CHL" { $1 = "Chile" } 
 $1 == "AUS" { $1 = "Autralia" } 
 $1 == "ZAF" { $1 = "South Africa" } 
 $1 == "TUR" { $1 = "Turkey" } 
 $1 == "KOR" { $1 = "South Korea" } 
 $1 == "CHN" { $1 = "China" } 
 $1 == "PER" { $1 = "Peru" } 
 $1 == "IRN" { $1 = "Iran" } 
 $1 == "SAU" { $1 = "Saudi Arabia" } 
 $1 == "RUS" { $1 = "Russia" } 
 $1 == "WLD" { $1 = "World" } 
 $1 == "PAK" { $1 = "Pakistan" } 
 $1 == "ETH" { $1 = "Ethiopia" } 
 $1 == "COL" { $1 = "Colombia" } 
 $1 == "BRA" { $1 = "Brazil" } 
 $1 == "MEX" { $1 = "Mexico" } 
 $1 == "UKR" { $1 = "Ukraine" } 
 $1 == "KAZ" { $1 = "Kazakhstan" } 
 $1 == "ISR" { $1 = "Israel" } 
 $1 == "NZL" { $1 = "New Zealand" } 
 $1 == "CAN" { $1 = "Canada" } 
 $1 == "THA" { $1 = "Thailand" } 
 $1 == "MYS" { $1 = "Malaysia" } 
 $1 == "PRY" { $1 = "Paraguay" } 
 $1 == "JPN" { $1 = "Japan" } 
 $1 == "CHE" { $1 = "Switzerland" } 
 $1 == "NGA" { $1 = "Nigeria" } 
 
 START && $4 == "KG_CAP" { data[$1][$3][$6] = $7 }  # data[country][type of meat][year] = kg per capita

 END {  print "{"
        print "\"source\":\"" SOURCE "\", "
        print "\"link\":\"" LINK "\", "
        print "\"license\":\"" LICENSE "\", "
        print "\"info\":\"" INFO "\", "
        print "\"accessed\":\"" ACCESSDATE "\", "
        print "\"data\": ["

        n=split("SHEEP BEEF PIG POULTRY", meats, " "); # need to step thru array in specific sequence
        firstcountry=1
        for (COUNTRY in data) {
          if (!firstcountry) print ","
          firstcountry=0
          printf "\n{\"country\":\"%s\",\"datasets\":[", COUNTRY
                    
          for (i=1; i<=n; i++) {                     
            if (i>1) print ","

            printf "{\"label\":\"%s\",\"data\":[", meatName[meats[i]]
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

