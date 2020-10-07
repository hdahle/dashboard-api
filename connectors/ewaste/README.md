# Global E-Waste

The data is from the Global E-Waste 2020, 2017 and 2014 reports

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. THere is no need for adding anything to cron since this is static data.

````
# redis key is globalewaste-2020
# data is in irena.json
redis-cli -x set globalewaste-2020 < globalewaste.json 

# verify that the data made it into redis
redis-cli get globalewaste-2020

# pretty print the output
redis-cli get globalewaste-2020 | jq .
````
### Accessing the data
````
https://api.dashboard.eco/globalewaste-2020
````
