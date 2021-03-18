#!/bin/sh
#
# Wrapper for eia.js
# Note that EIA API Key is in eiakey.txt
# eiakey.txt is owned by root and not tracked by github
# Create your own EIA API key: https://www.eia.gov/opendata/register.cfm
#
# H. Dahle 2020

eiaapikeyfile='eiakey.txt'
jsfile='eia.js'
jsfile2='eia-gdp-pop-co2.js'
jsfile3='eia-all-countries.js'

# Make sure eiakey exists
if [ ! -f "${eiaapikeyfile}" ]; then
  echo "EIA API key file not found: ${eiaapikeyfile} "
  exit
fi

# read EIA KEY
eiakey=`cat ${eiaapikeyfile}`
echo "Using EIA API key: ${eiakey}"

# Make sure JS file exists
if [ ! -f "${jsfile}" ]; then
  echo "JS file not found: ${jsfile}"
fi

# Request Coal, Oil and Gas data
for i in "electricity" "coal" "oil" "emissions" "population" "gdp" "nuclear"; do
  rediskey="eia-global-${i}"
  node ${jsfile} --series ${i} --apikey ${eiakey} --key ${rediskey} 
done

for i in "gas" "renewable-gen" "nuclear-gen" "fossilfuel-gen";  do
  rediskey="eia-global-${i}"
  node ${jsfile} --series ${i} --apikey ${eiakey} --key ${rediskey} 
done

# now run the second file which uses the output of the above
# stores to eia-global-gdp-pop-co2
node ${jsfile2} --scope world

# merge gdp/co2/pop on a region level
for i in "gdp" "emissions" "population"; do
  rediskey="eia-global-${i}"
  node ${jsfile3} --series ${i} --apikey ${eiakey} --key ${rediskey}   
done

# merge gdp/co2/pop on a country level
# stores to eia-global-gdp-pop-co2-REGION
for i in "WORL" "AFRC" "EURO" "EURA" "MIDE" "NOAM" "CSAM" "ASIA" "ASOC" "OCEA"; do
  node ${jsfile2} --scope country --region ${i}    
done
