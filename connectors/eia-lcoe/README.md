# EIA Report on LCOE / Cost of Electricity Generation in 2025

The data is from the EIA 2020 report, there is no data online AFAIK.

So I just typed up the JSON.

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. THere is no need for adding anything to cron since this is static data.

````
# redis key is eia-lcoe-2025
# data is in eia-lcoe.json
redis-cli -x set eia-lcoe-2025 < eia-lcoe.json 

# verify that the data made it into redis
redis-cli get eia-lcoe-2025

# pretty print the output
redis-cli get eia-lcoe-2025 | jq .
````
### Accessing the data
````
https://api.dashboard.eco/eia-lcoe-2025
````
