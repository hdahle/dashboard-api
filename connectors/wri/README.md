# CCS Circularity

The data is from the WRI report, there is no data online AFAIK.

So I just typed up the JSON.

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. There is no need for adding anything to cron since this is static data.

````
# redis key is wri-2016
# data is in wri.json
redis-cli -x set wri-2016 < wri.json 
````
### Accessing the data
````
https://api.dashboard.eco/wri-2016
````

### Source
````
https://www.wri.org/resources/data-visualizations/world-greenhouse-gas-emissions-2016
````