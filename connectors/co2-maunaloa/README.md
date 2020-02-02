# CO2-Maunaloa
This folder contains three connectors and they are all very similar:

1. co2-maunaloa.sh - grabs CO2 data from NOAA/ESRL
2. co2-maunaloa-sm.sh - also grabs CO2 data from NOAA/ESRL
3. ch4-maulanoa.sh - grabs CH4 (methane) data from NOAA/ESRL

The co2-maunaloa-sm.sh connector simply provides a subset of co2-maunaloa.sh, in order to reduce the amount of data read by the client. The data has been reduced from about 70 kbytes to 20kbytes.
