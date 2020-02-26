# CCS Circularity

The data is from the Circularity report, there is no data online AFAIK.

So I just typed up the JSON.

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. THere is no need for adding anything to cron since this is static data.

````
# redis key is circularity-2020
# data is in circularity.json
redis-cli -x set circularity-2020 < circularity.json 
````
### Accessing the data
````
https://api.dashboard.eco/circularity-2020
````
