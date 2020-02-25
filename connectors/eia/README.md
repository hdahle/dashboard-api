# EIA Global Oil/Coal/Gas

Global and regional production volumes of oil, coal and gas.

EIA updates this dataset once per year, and it is available through a nice REST API.

EIA requires an API Key. Get yours at 

````
https://www.eia.gov/opendata/register.cfm
````

Then store the API key into a text file "eiakey.txt". This file is used by the shell-script.

### Cron

To-do: Make an installer that adds to crontab, to make sure data is updated. Probably once a month, since the publishing data is unclear.
