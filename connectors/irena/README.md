# IRENA Report on Cost of Renewable Power Generation

The data is from the IRENA 2020 report, there is no data online AFAIK.

So I just typed up the JSON.

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. THere is no need for adding anything to cron since this is static data.

````
# redis key is irena-2020
# data is in irena.json
redis-cli -x set irena-2020 < irena.json 

# verify that the data made it into redis
redis-cli get irena-2020

# pretty print the output
redis-cli get irena-2020 | jq .
````
### Accessing the data
````
https://api.dashboard.eco/irena-2020
````
