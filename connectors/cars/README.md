# CCS Circularity

The data is from the Polestar report, page 20 of 38

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. There is no need for adding anything to cron since this is static data.

````
# redis key is polestar
# data is in polestar.json
redis-cli -x set polestar < polestar.json 
````
### Accessing the data
````
https://api.dashboard.eco/polestar
````
