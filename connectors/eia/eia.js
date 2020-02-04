// eia.js
//
// Fetches coal production data from api.eia.gov
// Fetches from all 8 global regions
// Reult from EIA is JSON, but we convert to more useful format
//
// H. Dahle, 2020

var fetch = require('node-fetch');
var redis = require('redis');
var redClient = redis.createClient();
var moment = require('moment');
const momFmt = 'YY-MM-DD hh:mm:ss';
const apiKey = '5b9ba590615f3bc01e0b18c8cdd021a7';


redClient.on('connect', function () {
  console.log(moment().format(momFmt) + ' Redis client connected');
});
redClient.on('ready', function () {
  console.log(moment().format(momFmt) + ' Redis client ready');
});
redClient.on('warning', function () {
  console.log(moment().format(momFmt) + ' Redis warning');
});
redClient.on('error', function (err) {
  console.log(moment().format(momFmt) + ' Redis error:' + err);
});

//
// Fetch EIA data
//
function goFetch() {
  function status(response) {
    if (response.status >= 200 && response.status < 300) {
      return Promise.resolve(response)
    } else {
      return Promise.reject(new Error(response.statusText))
    }
  }
  function json(response) {
    return response.json()
  }

  const eiaUnit = 'MT.A';
  const eiaRegions = [
    { region: 'Africa', code: 'AFRC' },
    { region: 'World', code: 'WORL' },
    { region: 'Europe', code: 'EURO' },
    { region: 'EU28', code: 'EU27' },
    { region: 'Middle East', code: 'MIDE' },
    { region: 'Eurasia', code: 'EURA' },
    { region: 'Asia and Oceania', code: 'ASOC' },
    { region: 'Latin America', code: 'CSAM' },
    { region: 'North America', code: 'NOAM' }
  ];

  let urls = [];
  eiaRegions.forEach(e => {
    urls.push('https://api.eia.gov/series/?api_key=' + apiKey
      + '&series_id=INTL.7-1-' + e.code
      + '-' + eiaUnit);
  });

  Promise.all(urls.map(url => fetch(url)
    .then(status)
    .then(json)
    .then(results => {
      if ((results.series.length === 0) || (results.series[0].data.length === 0)) {
        console.log('No data from api.eia.gov', results);
        return;
      }
      let series = results.series[0];
      let res = {
        source: series.source,
        accessed: series.updated,
        license: 'Copyright:' + series.copyright,
        link: 'https://api.eia.gov/',
        info: 'Units:' + series.units,
        //region: e.region,
        name: series.name,
        // convert EIA data array from [[],[],...] to [{},{},...]
        data: series.data.map(x => ({
          x: parseInt(x[0], 10), // convert year to number
          y: x[1]                // data value
        }))
      };

      // Store key/value pair to Redis
      let redisKey = 'eia-' + series.series_id;
      let redisValue = JSON.stringify(res);
      console.log(moment().format(momFmt) +
        ' Storing ' + redisValue.length +
        ' bytes, key=' + redisKey +
        ' value=' + redisValue);//.substring(0, 60));

      redClient.set(redisKey, redisValue, function (error, result) {
        if (result) {
          console.log(moment().format(momFmt) + ' Result:' + result);
        }
        else {
          console.log(moment().format(momFmt) + ' Error: ' + error);
        }
      });
    })
    .catch(err => console.log(err))
  ))
    .then(results => {
      setInterval((() => {
        process.exit();
      }), 2000)
    });
}

goFetch();