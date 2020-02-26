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
for i in "coal" "oil" "gas" "emissions" "population" "gdp" "nuclear"; do
  rediskey="eia-global-${i}"
  node ${jsfile} --series ${i} --apikey ${eiakey} --key ${rediskey} 
done
