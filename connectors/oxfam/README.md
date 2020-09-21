# Oxfam/Swedish Environment Institute Carbon Inequality

The data is from the Oxfam/SEI report.

So I just typed up the JSON.

### To-do: Script to add JSON to Redis
There should be a shell script that updates Redis with the JSON data. There is no need for adding anything to cron since this is static data.

````
# redis key is ofxam-2020
# data is in oxfam-2020.json
redis-cli -x set oxfam-2020 < oxfam-2020.json 
````
### Accessing the data
````
https://api.dashboard.eco/oxfam-2020
````

### Source
````
https://oxfamilibrary.openrepository.com/bitstream/handle/10546/621052/mb-confronting-carbon-inequality-210920-en.pdf

21 september 2020
````