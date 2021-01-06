# Global E-Waste

The data is from "The United States’ contribution of plastic waste to land and ocean", K.L.Law et.al.

Science Advances  30 Oct 2020:

Vol. 6, no. 44, eabd0288

DOI: 10.1126/sciadv.abd0288

https://advances.sciencemag.org/content/6/44/eabd0288

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. THere is no need for adding anything to cron since this is static data.

````
# redis key is plastic-waste-2016
# data is in plastic-waste.json
redis-cli -x set plastic-waste-2016 < plastic-waste.json 

# verify that the data made it into redis
redis-cli get plastic-waste-2016

# pretty print the output
redis-cli get plastic-waste-2016 | jq .
````
### Accessing the data
````
https://api.dashboard.eco/plastic-waste-2016
````
