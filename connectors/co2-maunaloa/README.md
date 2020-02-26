# CO2-Maunaloa
This folder contains four connectors and they are all very similar:

1. co2-maunaloa.sh - monthly CO2 time-series data from NOAA/ESRL
2. co2-maunaloa-sm.sh - monthly CO2 time-series data from NOAA/ESRL (more compact)
3. ch4-maulanoa.sh - monthly CH4 (methane) time-series data from NOAA/ESRL
4. co2-maunaloa-daily.sh - daily CO2 snapshot

The co2-maunaloa-sm.sh connector simply provides a compact subset of co2-maunaloa.sh, in order to reduce the amount of data read by the client. The data has been reduced from about 70 kbytes to 20kbytes.

The co2-maunaloa-daily.sh connector is simply a snapshot of atmospheric CO2 level today. 

### Cron

The installers add the scripts to crontab. The co2-maunaloa-daily.sh script runs daily (!), the others run monthly.
