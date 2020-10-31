# Plastic Waster Per Capita

The data is from the K.L.Law report, there is no data online AFAIK.

So I just typed up the JSON.

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. There is no need for adding anything to cron since this is static data.

````
# redis key is plastic-waste-2020
# data is in plastic-waste-2020.json
redis-cli -x set plastic-waste-2020 < plastic-waste-2020.json 
````
### Accessing the data
````
https://api.dashboard.eco/plastic-waste-2020
````

### Source
````
https://advances.sciencemag.org/content/6/44/eabd0288/tab-figures-data
````