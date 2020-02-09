// eia.js
//
// Fetches coal/oil/gas production data from api.eia.gov
// Fetches from all 8 global regions
// Reult from EIA is JSON, but we convert to chart.js-friendly format
//
// H. Dahle, 2020

var fetch = require('node-fetch');
var redis = require('redis');
var redClient = redis.createClient();
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';

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

// Fetch EIA data
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

  // process commandline
  let apiKey = argv.apikey; // filename from cmd line
  let redisKey = argv.key; // redis-key from cmd line
  let fuel = argv.fuel; // coal, oil or gas

  if (apiKey === undefined || redisKey === undefined || fuel === undefined) {
    console.log('Usage: node eia.js --fuel <coal|oil|gas> --apikey <apikey> ---key <rediskey>')
    process.exit();
  }

  // create components of query
  let eiaUnit = '';
  let eiaSeriesName = '';
  if (fuel === 'coal') {
    eiaUnit = 'MT.A';
    eiaSeriesName = 'INTL.7-1-';
  } else if (fuel === 'oil') {
    eiaUnit = 'TBPD.A';
    eiaSeriesName = 'INTL.55-1-';
  } else if (fuel === 'gas') {
    eiaUnit = 'BCM.A';
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

  fetch(url)
    .then(status)
    .then(json)
    .then(results => {
      // results.series is undefined if incorrect query URL
      if ((results.series === undefined) || (results.series.length === 0) ||
        (results.series[0].data === undefined) || (results.series[0].data.length === 0)) {
        console.log('No data from api.eia.gov', results);
        process.exit();
      }

      // original EIA data array is:   [ [year,value], [], ...]
      // convert to chart.js-friendly: [ {year,value}, {}, ...]
      results.series.forEach(series => {
        let d = series.data;
        series.data = d.map(x => ({
          x: parseInt(x[0], 10),
          y: Math.round(x[1] * 100) / 100
        }));
      })

      // add chart.js-friendly region-name to each series
      // this avoids client having to do this
      results.series.forEach(s => {
        eiaRegions.forEach(r => {
          if (s.series_id.indexOf(r.code) > -1) {
            s.region = r.region;
          }
        });
      });

      // sort based on production volumes -> chart easier to read
      results.series.sort((a, b) => a.data[0].y - b.data[0].y);

      // add 'source', 'link', 'accessed' key/values to JSON 
      // this is so that website can display this autmatically
      results.link = 'https://www.eia.gov/opendata/qb.php';
      results.source = results.series[0].source;
      results.accessed = results.series[0].updated;

      // Store key/value pair to Redis
      let redisValue = JSON.stringify(results);
      console.log(moment().format(momFmt) +
        ' Storing ' + redisValue.length +
        ' bytes, key=' + redisKey +
        ' value=' + redisValue.substring(0, 60));

      redClient.set(redisKey, redisValue, function (error, result) {
        if (result) {
          console.log(moment().format(momFmt) + ' Result:' + result);
        } else {
          console.log(moment().format(momFmt) + ' Error: ' + error);
        }
      });

      // exit
      setInterval((() => {
        process.exit();
      }), 1000)
    })
    .catch(err => console.log(err))
}

goFetch();