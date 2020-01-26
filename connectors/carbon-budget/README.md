# Carbon-budget 

The Global Carbon Project publishes two Excel files annually. The latest versions are
```
Global_Carbon_Budget_2019v1.0.xlsx
National_Carbon_Emissions_2019v1.0.xlsx
```
These files are described here: https://www.globalcarbonproject.org/carbonbudget/19/data.htm

This folder contains two NodeJS scripts for processing the CSV files, converting to JSON and optionally storing to Redis. Https://dashboard.eco then reads from Redis and creates nice charts. These scripts are very similar and should probably be combined into a single script:
```
national-carbon-emissions.js
fossil-emissions-by-fuel-type.js
```
The scripts follow the same recipe:

```js
  // parse input arguments: filename and Redis-key
  
  // verify file exists
  
  // then process CSV line-by-line
  fs.createReadStream(fn)
    .pipe(parse({ delimiter: ',' }))
    .on('data', csvRow => {
    // csvRow is an array of columns for a single row
    // place relevant data into an object
    })
    .on('end', () => {
      // file processing done, now create output data
      let s = JSON.stringify(d);
      
      // store to Redis 
      redClient.set(key, s, function (error, result) {
        // ...  
      });
    });
    // that's pretty much it
```
### Pre-requisites
The XLSX files must be downloaded from https://www.icos-cp.eu/GCP/2019, and then converted to CSV before processing. 
1. In the Global_Carbon_Budget file, the tab 'Fossil Emissions by Fuel Type' should be saved as CSV.
2. In the National_Carbon_Emissions file, the tab 'Territorial Emissions' should be saved as CSV.
The relevant NodeJS scripts should then be run on the files.

### Usage
```
node script --file <filename.csv> [ --key <optional-redis-key> ]  [ --countries <optional-country-list> ]
```
### Examples:

Process CSV file and output a JSON blob with all countries to stdout:
```
node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv
```
Process CSV file and store JSON blob with all countries to Redis, where '--key' specifies the Redis-key to use:
```
node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv --key "emissions-by-country"
```
Process CSV file and store JSON blob containing only certain countries/regions, where '--countries' should be followed by a comma-separated list of countries (the list must be in quotes if there is white space in any country/region name, see below):
```
node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv --key "emissions-by-region" --countries "EU28,Africa,Asia,Central America,Europe,Middle East,North America,South America,Oceania,Bunkers"
```
Process CSV file and store JSON blob containin only data for Norway:
```
node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv --key "emissions-norway" --countries Norway 
```
