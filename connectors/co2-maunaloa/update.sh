curl ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_trend_gl.txt > data.txt
node co2-daily.js  --file data.txt --key co2-daily
