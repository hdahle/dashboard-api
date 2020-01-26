# Carbon-budget 

NodeJS scripts for processing the files

### Usage
```
node script --file <filename.csv> [ --key <optional-redis-key> ]  [ --countries <optional-country-list> ]
```
### Examples:

Process CSV file and output a JSON blob with all countries to stdout:
```
node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv
```
Process CSV file and store JSON blob with all countries to Redis:
```
node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv --key "emissions-by-country"
```
Process CSV file and store JSON blob containing only certain countries/regions:
```
node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv --key "emissions-by-region" --countries "EU28,Africa,Asia,Central America,Europe,Middle East,North America,South America,Oceania,Bunkers"
```

Process CSV file and store JSON blob containin only data for Norway:
```
node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv --key "emissions-norway" --countries Norway 
```
