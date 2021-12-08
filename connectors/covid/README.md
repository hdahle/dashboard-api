# Covid data from Johns Hopkins

### Get two data files from the Johns Hopkins repo
These commands can also be run as ````npm run update````
````
echo "Get Covid data from JHU's CSSEGISandData repository"
curl "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_global.csv" > time_series_covid19_deaths_global.csv
curl "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv" > time_series_covid19_confirmed_global.csv
````

### Process the CSV files into JSON data
I added the relevant commands into ````package.json```` so thay you can simply do ````npm run deaths````
````
"deaths": "node covid2.js --file time_series_covid19_deaths_global.csv --key covid-deaths",
"confirmed": "node covid2.js --file time_series_covid19_confirmed_global.csv --key covid-confirmed",
"summarydeaths": "node covid2.js --file time_series_covid19_deaths_global.csv --key covid-deaths-summary --summaryOnly",
"summaryconfirmed": "node covid2.js --file time_series_covid19_confirmed_global.csv --key covid-confirmed-summary --summaryOnly",
"regions": "node covid2.js --countries regions --file time_series_covid19_deaths_global.csv --key covid-deaths-regions",
"top20": "node covid2.js --countries top20 --file time_series_covid19_deaths_global.csv --key covid-deaths-top20",
"select": "node covid2.js --countries US,UK,Spain,Italy,France,World,Norway,Denmark,Sweden --file time_series_covid19_deaths_global.csv --key covid-deaths-select",
"world": "node covid2.js --countries World --file time_series_covid19_deaths_global.csv --key covid-deaths-world"
````

Put this into ````crontab```` for daily processing:
````
03 6,8,10 * * * cd /home/bitnami/dashboard-api/connectors/covid && /opt/bitnami/nodejs/bin/node covid2.js --countries World,US,UK,France,Italy,Spain,Norway,India,Brazil --file time_series_covid19_deaths_global.csv --key covid-deaths-select  >> /home/bitnami/log/cron.log 2>&1
04 6,8,10 * * * cd /home/bitnami/dashboard-api/connectors/covid && /opt/bitnami/nodejs/bin/node covid2.js --countries regions --file time_series_covid19_deaths_global.csv --key covid-deaths-regions >> /home/bitnami/log/cron.log 2>&1
05 6,8,10 * * * cd /home/bitnami/dashboard-api/connectors/covid && /opt/bitnami/nodejs/bin/node covid2.js --countries top20 --file time_series_covid19_deaths_global.csv --key covid-deaths-top >> /home/bitnami/log/cron.log 2>&1
06 6,8,10 * * * cd /home/bitnami/dashboard-api/connectors/covid && /opt/bitnami/nodejs/bin/node covid2.js --file time_series_covid19_deaths_global.csv --key covid-deaths-summary >> /home/bitnami/log/cron.log 2>&1
07 6,8,10 * * * cd /home/bitnami/dashboard-api/connectors/covid && /opt/bitnami/nodejs/bin/node covid2.js --file time_series_covid19_confirmed_global.csv --key covid-confirmed-summary >> /home/bitnami/log/cron.log 2>&1
08 6,8,10 * * * cd /home/bitnami/dashboard-api/connectors/covid && /opt/bitnami/nodejs/bin/node covid2.js --summaryOnly --file time_series_covid19_deaths_global.csv --key covid-countries >> /home/bitnami/log/cron.log 2>&1
````
