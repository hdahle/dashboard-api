#!/bin/sh

# Convert CSV file to JSON
#
# H. Dahle

REDIS=$1
USERDIR=`eval echo ~${USER}`
CSVDIR="${USERDIR}/covid/csse_covid_19_data/csse_covid_19_time_series"
if [ "$REDIS" = "" ]; then
  REDIS="redis-cli"
else
  if [ ! -f ${REDIS} ]; then
    echo `date` "Not found: ${REDIS}"
    exit 1
  fi
fi

TMPDIR=$(mktemp -d)
DATE=`date`

for i in "confirmed" "deaths" ; do
  CSVFILE="${CSVDIR}/time_series_covid19_${i}_global.csv"
  if [ -f "${CSVFILE}" ]; then
    echo -n `date` "Downloaded CSV-file, lines: "
    cat ${CSVFILE} | wc -l    
    LINES=`cat ${CSVFILE} | wc -l`
    if [ "$LINES" -eq "0" ]; then
      echo `date` "Error: empty file ${CSVFILE}, aborting"
      exit 1
    fi
  else
    echo `date` "File not found: ${CSVFILE}, aborting "
    exit 1
  fi
  REDISKEY="covid-${i}"
  JSONFILE="${TMPDIR}/${REDISKEY}.json"
  echo `date` "Converting Covid data from CSV to JSON: ${i}"

# CSV input:

#Province/State,Country/Region,Lat,Long,1/22/20,1/23/20,1/24/20,1/25/20,1/26/20,1/27/20,1/28/20,1/29/20,1/30/20,1/31/20,2/1/20,2/2/20,2/3/20,2/4/20,2/5/20,2/6/20,2/7/20,2/8/20,2/9/20,2/10/20,2/11/20,2/12/20,2/13/20,2/14/20,2/15/20,2/16/20,2/17/20,2/18/20,2/19/20,2/20/20,2/21/20,2/22/20,2/23/20,2/24/20,2/25/20,2/26/20,2/27/20,2/28/20,2/29/20,3/1/20,3/2/20,3/3/20,3/4/20,3/5/20
#Anhui,Mainland China,31.8257,117.2264,1,9,15,39,60,70,106,152,200,237,297,340,408,480,530,591,665,733,779,830,860,889,910,934,950,962,973,982,986,987,988,989,989,989,989,989,989,990,990,990,990,990,990,990
#Beijing,Mainland China,40.1824,116.4142,14,22,36,41,68,80,91,111,114,139,168,191,212,228,253,274,297,315,326,337,342,352,366,372,375,380,381,387,393,395,396,399,399,399,400,400,410,410,411,413,414,414,418,418
#Chongqing,Mainland China,30.0572,107.874,6,9,27,57,75,110,132,147,182,211,247,300,337,366,389,411,426,428,468,486,505,518,529,537,544,551,553,555,560,567,572,573,575,576,576,576,576,576,576,576,576,576,576,576

# Turn it into a JSON blob

  cat ${CSVFILE} | sed 's/\"Korea, South\"/South Korea/' | sed 's/The Bahamas/Bahamas/' | sed 's/\"Gambia, The\"/Gambia/' | sed 's/\"Bahamas, The\"/Bahamas/' | gawk -v d="${DATE}" 'BEGIN {ORS=""
            FS=","
            population["China"] = 1433783686;
            population["Mainland China"] = 1433783686;
            population["India"] = 1366417754;
            population["US"] = 329064917;
            population["Indonesia"] = 270625568;
            population["Pakistan"] = 216565318;
            population["Brazil"] = 211049527;
            population["Nigeria"] = 200963599;
            population["Bangladesh"] = 163046161;
            population["Russia"] = 145872256;
            population["Mexico"] = 127575529;
            population["Japan"] = 126860301;
            population["Ethiopia"] = 112078730;
            population["Philippines"] = 108116615;
            population["Egypt"] = 100388073;
            population["Vietnam"] = 96462106;
            population["DR Congo"] = 86790567;
            population["Germany"] = 83517045;
            population["Turkey"] = 83429615;
            population["Iran"] = 82913906;
            population["Thailand"] = 69037513;
            population["UK"] = 67530172;
            population["France"] = 65129728;
            population["Italy"] = 60550075;
            population["South Africa"] = 58558270;
            population["Tanzania"] = 58005463;
            population["Myanmar"] = 54045420;
            population["Kenya"] = 52573973;
            population["South Korea"] = 51225308;
            population["Colombia"] = 50339443;
            population["Spain"] = 46736776;
            population["Argentina"] = 44780677;
            population["Uganda"] = 44269594;
            population["Ukraine"] = 43993638;
            population["Algeria"] = 43053054;
            population["Sudan"] = 42813238;
            population["Iraq"] = 39309783;
            population["Afghanistan"] = 38041754;
            population["Poland"] = 37887768;
            population["Canada"] = 37411047;
            population["Morocco"] = 36471769;
            population["Saudi Arabia"] = 34268528;
            population["Uzbekistan"] = 32981716;
            population["Peru"] = 32510453;
            population["Malaysia"] = 31949777;
            population["Angola"] = 31825295;
            population["Mozambique"] = 30366036;
            population["Yemen"] = 29161922;
            population["Ghana"] = 28833629;
            population["Nepal"] = 28608710;
            population["Venezuela"] = 28515829;
            population["Madagascar"] = 26969307;
            population["North Korea"] = 25666161;
            population["Ivory Coast"] = 25716544;
            population["Cameroon"] = 25876380;
            population["Australia"] = 25203198;
            population["Taiwan"] = 23773876;
            population["Niger"] = 23310715;
            population["Sri Lanka"] = 21323733;
            population["Burkina Faso"] = 20321378;
            population["Mali"] = 19658031;
            population["Romania"] = 19364557;
            population["Malawi"] = 18628747;
            population["Chile"] = 18952038;
            population["Kazakhstan"] = 18551427;
            population["Zambia"] = 17861030;
            population["Guatemala"] = 17581472;
            population["Ecuador"] = 17373662;
            population["Netherlands"] = 17097130;
            population["Syria"] = 17070135;
            population["Cambodia"] = 16486542;
            population["Senegal"] = 16296364;
            population["Chad"] = 15946876;
            population["Somalia"] = 15442905;
            population["Zimbabwe"] = 14645468;
            population["Guinea"] = 12771246;
            population["Rwanda"] = 12626950;
            population["Benin"] = 11801151;
            population["Tunisia"] = 11694719;
            population["Belgium"] = 11539328;
            population["Bolivia"] = 11513100;
            population["Cuba"] = 11333483;
            population["Haiti"] = 11263770;
            population["South Sudan"] = 11062113;
            population["Burundi"] = 10864245;
            population["Dominican Republic"] = 10738958;
            population["Czech Republic"] = 10689209;
            population["Greece"] = 10473455;
            population["Portugal"] = 10226187;
            population["Jordan"] = 10101694;
            population["Azerbaijan"] = 10047718;
            population["Sweden"] = 10036379;
            population["United Arab Emirates"] = 9770529;
            population["Honduras"] = 9746117;
            population["Hungary"] = 9684679;
            population["Belarus"] = 9452411;
            population["Tajikistan"] = 9321018;
            population["Austria"] = 8955102;
            population["Papua New Guinea"] = 8776109;
            population["Serbia"] = 8772235;
            population["Switzerland"] = 8591365;
            population["Israel"] = 8519377;
            population["Togo"] = 8082366;
            population["Sierra Leone"] = 7813215;
            population["Hong Kong"] = 7436154;
            population["Laos"] = 7169455;
            population["Paraguay"] = 7044636;
            population["Bulgaria"] = 7000119;
            population["Lebanon"] = 6855713;
            population["Libya"] = 6777452;
            population["Nicaragua"] = 6545502;
            population["El Salvador"] = 6453553;
            population["Kyrgyzstan"] = 6415850;
            population["Turkmenistan"] = 5942089;
            population["Singapore"] = 5804337;
            population["Denmark"] = 5771876;
            population["Finland"] = 5532156;
            population["Slovakia"] = 5457013;
            population["Congo"] = 5380508;
            population["Norway"] = 5378857;
            population["Costa Rica"] = 5047561;
            population["Palestine"] = 4981420;
            population["Oman"] = 4974986;
            population["Liberia"] = 4937374;
            population["Ireland"] = 4882495;
            population["New Zealand"] = 4783063;
            population["Central African Republic"] = 4745185;
            population["Mauritania"] = 4525696;
            population["Panama"] = 4246439;
            population["Kuwait"] = 4207083;
            population["Croatia"] = 4130304;
            population["Moldova"] = 4043263;
            population["Georgia"] = 3996765;
            population["Eritrea"] = 3497117;
            population["Uruguay"] = 3461734;
            population["Bosnia and Herzegovina"] = 3301000;
            population["Mongolia"] = 3225167;
            population["Armenia"] = 2957731;
            population["Jamaica"] = 2948279;
            population["Puerto Rico"] = 2933408;
            population["Albania"] = 2880917;
            population["Qatar"] = 2832067;
            population["Lithuania"] = 2759627;
            population["Namibia"] = 2494530;
            population["Gambia"] = 2347706;
            population["Botswana"] = 2303697;
            population["Gabon"] = 2172579;
            population["Lesotho"] = 2125268;
            population["North Macedonia"] = 2083459;
            population["Slovenia"] = 2078654;
            population["Guinea-Bissau"] = 1920922;
            population["Latvia"] = 1906743;
            population["Bahrain"] = 1641172;
            population["Trinidad and Tobago"] = 1394973;
            population["Equatorial Guinea"] = 1355986;
            population["Estonia"] = 1325648;
            population["East Timor"] = 1293119;
            population["Mauritius"] = 1198575;
            population["Cyprus"] = 1179551;
            population["Eswatini"] = 1148130;
            population["Djibouti"] = 973560;
            population["Fiji"] = 889953;
            population["Réunion"] = 888927;
            population["Comoros"] = 850886;
            population["Guyana"] = 782766;
            population["Bhutan"] = 763092;
            population["Solomon Islands"] = 669823;
            population["Macau"] = 640445;
            population["Montenegro"] = 627987;
            population["Luxembourg"] = 615729;
            population["Western Sahara"] = 582463;
            population["Suriname"] = 581372;
            population["Cape Verde"] = 549935;
            population["Maldives"] = 530953;
            population["Guadeloupe"] = 447905;
            population["Malta"] = 440372;
            population["Brunei"] = 433285;
            population["Belize"] = 390353;
            population["Bahamas"] = 389482;
            population["Martinique"] = 375554;
            population["Iceland"] = 339031;
            population["Vanuatu"] = 299882;
            population["Barbados"] = 287025;
            population["New Caledonia"] = 282750;
            population["French Guiana"] = 282731;
            population["French Polynesia"] = 279287;
            population["Mayotte"] = 266150;
            population["São Tomé and Príncipe"] = 215056;
            population["Samoa"] = 197097;
            population["Saint Lucia"] = 182790;
            population["Guernsey and Jersey"] = 172259;
            population["Guam"] = 167294;
            population["Curacao"] = 163424;
            population["Kiribati"] = 117606;
            population["F.S. Micronesia"] = 113815;
            population["Grenada"] = 112003;
            population["Tonga"] = 110940;
            population["Saint Vincent and the Grenadines"] = 110589;
            population["Aruba"] = 106314;
            population["U.S. Virgin Islands"] = 104578;
            population["Seychelles"] = 97739;
            population["Antigua and Barbuda"] = 97118;
            population["Isle of Man"] = 84584;
            population["Andorra"] = 77142;
            population["Dominica"] = 71808;
            population["Cayman Islands"] = 64948;
            population["Bermuda"] = 62506;
            population["Marshall Islands"] = 58791;
            population["Greenland"] = 56672;
            population["Northern Mariana Islands"] = 56188;
            population["American Samoa"] = 55312;
            population["Saint Kitts and Nevis"] = 52823;
            population["Faroe Islands"] = 48678;
            population["Sint Maarten"] = 42388;
            population["St. Martin"] = 42388;
            population["Monaco"] = 38964;
            population["Turks and Caicos Islands"] = 38191;
            population["Liechtenstein"] = 38019;
            population["San Marino"] = 33860;
            population["Gibraltar"] = 33701;
            population["British Virgin Islands"] = 30030;
            population["Caribbean Netherlands"] = 25979;
            population["Palau"] = 18008;
            population["Cook Islands"] = 17548;
            population["Anguilla"] = 14869;
            population["Tuvalu"] = 11646;
            population["Wallis and Futuna"] = 11432;
            population["Nauru"] = 10756;
            population["Saint Helena; Ascension and Tristan da Cunha"] = 6059;
            population["Saint Barthelemy"] = 9800;
            population["Saint Pierre and Miquelon"] = 5822;
            population["Montserrat"] = 4989;
            population["Diamond Princess"] = 3711;
            population["Others"] = 3711;
            population["Falkland Islands"] = 3377;
            population["Niue"] = 1615;
            population["Tokela"] = 1340;
            population["Vatican City"] = 799;

            print "{"
            print "\"source\":\"2019 Novel Coronavirus COVID-19 (2019-nCoV) Data Repository by Johns Hopkins CSSE, https://systems.jhu.edu. Population figures from Wikipedia/UN\", "
            print "\"link\":\"https://github.com/CSSEGISandData/COVID-19\", "
            print "\"license\":\"README.md in the Github repo says: This GitHub repo and its contents herein, including all data, mapping, and analysis, copyright 2020 Johns Hopkins University, all rights reserved, is provided to the public strictly for educational and academic research purposes. The Website relies upon publicly available data from multiple sources, that do not always agree. The Johns Hopkins University hereby disclaims any and all representations and warranties with respect to the Website, including accuracy, fitness for use, and merchantability. Reliance on the Website for medical guidance or use of the Website in commerce is strictly prohibited\", "
            print "\"accessed\":\"" d "\", "
            print "\"legend\":\"Data for France includes St Barts. Data for Italy includes the Vatican and San Marino. Cruise ship Diamond Princess is reported as a separate country. The timeseries data per country is an array [{t:date,y:numberOfCases,ypm:casesPerMillion},{},...] \", "
            print "\"data\": ["
     }

     # Skip comments
     /^#/  {next}

     # Sometimes dataset has a missing last datum
     $NF == "" {  $NF = 0 }

     # Some ad-hoc groupings of entities, renaming of entities
     $2=="San Marino" { $2="Italy"}
     $2=="Vatican City" { $2="Italy"}
     $2=="Saint Barthelemy" { $2="France"}
     $2=="Mainland China" { $2="China"}
     $2=="Iran (Islamic Republic of)" { $2="Iran" }
     $2=="Hong Kong SAR" { $2="Hong Kong" }
     $2=="Taipei and environs" { $2="Taiwan" }
     $2=="Republic of Ireland" { $2="Ireland" }
     $2=="Republic of Korea" { $2="South Korea" }

     # This line contains the list of dates, from $5 to $NF
     # Save the list of dates in the dates[] array
     $1=="Province/State" { 
            # Save original number of fields for later use
            NUMF = NF
            # Step through all the dates which are in m/d/yy format
            for (i=5; i<=NF; i++) {
              split($i, date, "/")
              if (date[1] > 13 || date[1]<1 ) {
                print "Error in date: " $0
                exit
              }
              # Save all date fields in the new format: "1/31/20" => "2020-01-31"
              if (date[2]<10) date[2] = "0" date[2]
              if (date[1]<10) date[1] = "0" date[1]
              dates[i] = "20"  substr(date[3],1,2) "-" date[1] "-" date[2]
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
     if (country == "US" && NUMF!=NF) {
              $NF = $(NF-1) 
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
         if (!firstcountry) print ","
         firstcountry = 0
         pop = population[country]
         popworld += pop
         print "{\"country\":\"" country "\","
         print "\"population\":" (pop ? pop:"null") ","
         print "\"data\":["
         first = 1;
         prev = 0;
         numyesterday = 0

         for (j in data[country]) {
           if (!first) print ","
           cases = data[country][j]
           data["World"][j] += cases
           print "{\"t\":\"" dates[j] "\",\"y\":" cases
           numtoday = cases-prev
           print ", \"d\":" cases-prev
           printf ", \"c\":%d", numtoday - numyesterday
           printf ", \"cp\":%.2f", numyesterday?((numtoday - numyesterday)/numyesterday):0
           prev=cases
           numyesterday=numtoday
           if (pop) {
             printf ",\"ypm\":%.2f}", 1000000*cases/pop
           } else {
             print ",\"ypm\":null}"
           }
           first = 0
         }
         print "]}"
       }       
       print ","

       pop = popworld       
       country="World"
       print "{\"country\":\"" country "\","
       print "\"population\":" pop ","
       print "\"data\":["
       first = 1
       prev = 0
       numyesterday = 0
       for (j in data[country]) {
         if (!first) print ","
         cases = data[country][j]
         print "{\"t\":\"" dates[j] "\",\"y\":" cases
         numtoday = cases-prev
         print ", \"d\":" cases-prev         
         printf ", \"c\":%d", numtoday - numyesterday
         printf ", \"cp\":%.2f", numyesterday?((numtoday - numyesterday)/numyesterday):0
         prev=cases
         numyesterday=numtoday
         if (pop) {
           printf ",\"ypm\":%.2f}", 1000000*cases/pop
         } else {
           print ",\"ypm\":null}"
         }
         first = 0
       }
       print "]}"
       print " ]}"}' > ${JSONFILE}

  echo -n `date` "Storing JSON to Redis, bytes: "
  cat ${JSONFILE} | wc --bytes 

  echo -n `date` "Saving JSON to Redis with key ${REDISKEY}, result: "
  ${REDIS} -x set ${REDISKEY} < ${JSONFILE}

  echo -n `date` "Retrieving key=${REDISKEY} from Redis, bytes: "
  ${REDIS} get ${REDISKEY} | wc --bytes

done

exit 0
