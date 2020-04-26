#!/bin/sh

# slightly malformed input data
input_start=2020-1-1
input_end=2020-3-1

# After this, startdate and enddate will be valid ISO 8601 dates,
# or the script will have aborted when it encountered unparseable data
# such as input_end=abcd

startdate=$(date -I -d "$input_start") || exit -1
enddate=$(date -I -d "$input_end")     || exit -1

d="$startdate"
while [ "$d" != "$enddate" ]; do 
  echo $d

  node schiphol.js --date $d --appID `cat app.id` --appKey `cat app.key` --key schiphol

  d=$(date -I -d "$d + 1 day")
  sleep 10
done