# NVE Report on LCOE / Cost of Electricity Generation in 2021 and 2030

Data source: 
https://www.nve.no/energi/analyser-og-statistikk/kostnader-for-kraftproduksjon/?ref=mainmenu

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. THere is no need for adding anything to cron since this is static data.

````
# redis key is nve-lcoe-2021
# data is in nve-lcoe.json
redis-cli -x set nve-lcoe-2021 < nve-lcoe.json 

# verify that the data made it into redis
redis-cli get nve-lcoe-2021

# pretty print the output
redis-cli get nve-lcoe-2021 | jq .
````
### Accessing the data
````
https://api.dashboard.eco/nve-lcoe-2021
````
