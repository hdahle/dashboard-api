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
(() => {
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
  let redisKey = argv.key;  // redis-key from cmd line
  let series = argv.series; // coal, oil or gas
  let endDate = argv.end;   // end date

  let region = argv.region; // region

  // These are the regions we always query for
  let eiaRegions = [
    { region: 'Africa', code: 'AFRC' },
    { region: 'World', code: 'WORL' },
    { region: 'Europe', code: 'EURO' },
    { region: 'EU28', code: 'EU27' },
    { region: 'Middle East', code: 'MIDE' },
    { region: 'Eurasia', code: 'EURA' },
    { region: 'Asia&Oceania', code: 'ASOC' },
    { region: 'S America', code: 'CSAM' },
    { region: 'N America', code: 'NOAM' },
    { region: 'USA', code: 'USA' },
    { region: 'China', code: 'CHN' },
    { region: 'India', code: 'IND' },
    { region: 'Japan', code: 'JPN' },
    { region: 'Russia', code: 'RUS' }
  ];

  // Series names and appropriate units for series
  const eiaSeries = {
    'coal': { eiaSeriesName: 'INTL.7-1-', eiaUnit: 'MT.A' },
    'oil': { eiaSeriesName: 'INTL.55-1-', eiaUnit: 'TBPD.A' },
    'gas': { eiaSeriesName: 'INTL.26-1-', eiaUnit: 'BCM.A' },
    'population': { eiaSeriesName: 'INTL.4702-33-', eiaUnit: 'THP.A' },
    'emissions': { eiaSeriesName: 'INTL.4008-8-', eiaUnit: 'MMTCD.A' },
    'nuclear': { eiaSeriesName: 'INTL.27-12-', eiaUnit: 'BKWH.A' },
    'gdp': { eiaSeriesName: 'INTL.4701-34-', eiaUnit: 'BDOLPPP.A' },
    'electricity': { eiaSeriesName: 'INTL.2-12-', eiaUnit: 'BKWH.A' },
    'coal-gen': { eiaSeriesName: 'INTL.7-12-', eiaUnit: 'BKWH.A' },
    'oil-gen': { eiaSeriesName: 'INTL.55-12-', eiaUnit: 'BKWH.A' },
    'gas-gen': { eiaSeriesName: 'INTL.26-12-', eiaUnit: 'BKWH.A' },
    'renewable-gen': { eiaSeriesName: 'INTL.29-12-', eiaUnit: 'BKWH.A' },
    'nuclear-gen': { eiaSeriesName: 'INTL.27-12-', eiaUnit: 'BKWH.A' },
    'fossilfuel-gen': { eiaSeriesName: 'INTL.28-12-', eiaUnit: 'BKWH.A' },
    'solar-gen': { eiaSeriesName: 'INTL.116-12-', eiaUnit: 'BKWH.A' },
    'wind-gen': { eiaSeriesName: 'INTL.37-12-', eiaUnit: 'BKWH.A' },
    'hydro-gen': { eiaSeriesName: 'INTL.33-12-', eiaUnit: 'BKWH.A' }
  };

  if (apiKey === undefined || redisKey === undefined || series === undefined || eiaSeries[series] === undefined) {
    console.log('Usage: node eia.js --series <seriesname> --apikey <apikey> --key <rediskey> [--end <endYear>] [--region <RegionName>]');
    let s = '';
    Object.keys(eiaSeries).forEach(x => s += x + ' ');
    console.log('  <seriesname> is one of: ', s);
    process.exit();
  }

  // Use a single region if it is specified. If not, query for all regions in eiaRegions
  if (region !== undefined) {
    const tmp = eiaRegions.filter(e => e.region === region)
    if (tmp.length) {
      eiaRegions = tmp;
    }
  }

  let { eiaSeriesName, eiaUnit } = eiaSeries[series];

  // build a single query URL, include all regions
  let url = 'https://api.eia.gov/series/?api_key=' + apiKey + '&series_id=';
  eiaRegions.forEach(element => {
    url += eiaSeriesName + element.code + '-' + eiaUnit + ';';
  });

  // If ending date was specified, use it. With no end date, EIA will return all data up to today
  if (endDate !== undefined) {
    let n = parseInt(endDate, 10);
    if (isNaN(n) || n < 2000 || n > parseInt(moment().format("YYYY"), 10)) {
      console.log('  <end> should be a valid year between 2000 and today');
      process.exit();
    }
    url += '&end=' + endDate;
  }

  fetch(url)
    .then(status)
    .then(json)
    .then(results => {
      // results.series is undefined if incorrect query URL
      if ((results.series === undefined) || (results.series.length === 0) ||
        (results.series[0].data === undefined) || (results.series[0].data.length === 0)) {
        console.log('No data from api.eia.gov: ', results, url);
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

      // sort regions based on production volumes -> chart easier to read
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
})();