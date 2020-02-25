# EIA Global Oil/Coal/Gas

Global and regional production volumes of oil, coal and gas.

EIA updates this dataset once per year, and it is available through a nice REST API.

### EIA API Key
EIA requires an API Key. Get yours at 

````
https://www.eia.gov/opendata/register.cfm
````

Then store the API key into a text file "eiakey.txt". This file is used by the shell-script.

### EIA API - Building the query URL
Units and names of data-series were figured out by poking around the API:
````javascript
  if (fuel === 'coal') {
    eiaUnit = 'MT.A'; // metric tons
    eiaSeriesName = 'INTL.7-1-';
  } else if (fuel === 'oil') {
    eiaUnit = 'TBPD.A'; // thousands of barrels per day
    eiaSeriesName = 'INTL.55-1-';
  } else if (fuel === 'gas') {
    eiaUnit = 'BCM.A'; // billion cubic meters
    eiaSeriesName = 'INTL.26-1-';
  }

  const eiaRegions = [
    { region: 'Africa', code: 'AFRC' },
    { region: 'World', code: 'WORL' },
    { region: 'Europe', code: 'EURO' },
    { region: 'EU28', code: 'EU27' },
    { region: 'Middle East', code: 'MIDE' },
    { region: 'Eurasia', code: 'EURA' },
    { region: 'Asia&Oceania', code: 'ASOC' },
    { region: 'S America', code: 'CSAM' },
    { region: 'N America', code: 'NOAM' }
  ];

  // build a single query URL, include all regions
  let url = 'https://api.eia.gov/series/?api_key=' + apiKey + '&series_id=';
  eiaRegions.forEach(element => {
    url += eiaSeriesName + element.code + '-' + eiaUnit + ';';
  });

  // fetch from EIA, massage the data, store to Redis
  fetch(url)
    .then(status)
    .then(json)
    .then(results => {
      // original EIA data array is:   [ [year,value], [], ...]
      // convert to chart.js-friendly: [ {year,value}, {}, ...]
      results.series.forEach(series => {
        let d = series.data;
        series.data = d.map(x => ({
          x: parseInt(x[0], 10),
          y: Math.round(x[1] * 100) / 100
        }));
      })
      
      // store the result to Redis
    })
    // done
````

### Cron (to-do)

To-do: Make an installer that adds to crontab, to make sure data is updated. Probably once a month, since the publishing data is unclear.
