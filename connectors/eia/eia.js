// eia.js
//
// Fetches coal/oil/gas production data from api.eia.gov
// Fetches from all 8 global regions
// Reult from EIA is JSON, but we convert to chart.js-friendly format
//
// H. Dahle, 2023

var fetch = require('node-fetch');
var redis = require('redis');
var argv = require('minimist')(process.argv.slice(2));

// Wrapper for node-fetch
// Arg can be {} for a simple GET
async function fetchJson(url, arg) {
  let json;
  try {
    const response = await fetch(url, arg);
    json = await response.json();
  } catch (error) {
    console.error(error);
  }
  return json;
}

// Connect to local redis
// Save key/value pair
// Close redis
function saveToRedis(key, value) {
  console.log('Storing ' + value.length +
    ' bytes, key=' + key +
    ' value=' + value.substring(0, 60));
  let redClient = redis.createClient();
  redClient.on('connect', function () {
    console.log('Redis client connected');
  });
  redClient.on('ready', function () {
    console.log('Redis client ready');
  });
  redClient.on('warning', function () {
    console.log('Redis warning');
  });
  redClient.on('error', function (err) {
    console.log('Redis error:' + err);
  });
  redClient.set(key, value, function (error, result) {
    if (result) {
      console.log('Result:' + result);
    } else {
      console.log('Error: ' + error);
    }
    redClient.quit();
  });
}

// Fetch EIA data
(async () => {
  function usage(msg) {
    console.log("Error:", msg);
    console.log('Usage: node eia.js --series <seriesname> --apikey <apikey> [--key <rediskey>]');
    console.log('  <apikey> is the alphanum code required for API access ');
    console.log('  <rediskey> is optional, required for storing result to Redis');
    console.log('    If <rediskey> is not used, output goes to stdout');
    let s = '';
    Object.keys(eiaSeries).forEach(x => s += x + ' ');
    console.log('  <seriesname> is one of: ', s);
  }
  // process commandline
  let apiKey = argv.apikey; // filename from cmd line
  let redisKey = argv.key;  // redis-key from cmd line
  let series = argv.series; // coal, oil or gas
  // mapping region names <-> EIA Region Codes
  const eiaRegionCodes = [
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
  // EIA Series names and appropriate units for series
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

  if (apiKey === undefined) {
    usage("Missing API key");
    return;
  }
  if (redisKey === true) {
    usage("Missing Redis key");
    return;
  }
  if (series === undefined) {
    usage("Series not specified");
    return;
  }
  if (eiaSeries[series] === undefined) {
    usage("Invalid series")
    return;
  }

  // Fetch data from all regions, one HTTPS GET per region
  const today = new Date();
  let results = {
    source: "US EIA Energy Information Administration",
    link: "https://www.eia.gov/",
    accessed: today.toUTCString(),
    data: {
      datasets: []
    }
  };

  // Perform one HTTPS GET per region, simplify results, then save results in results.data.datasets[]
  const { eiaSeriesName, eiaUnit } = eiaSeries[series];
  const eiaURL = 'https://api.eia.gov/v2/seriesid/';
  for (i = 0; i < eiaRegionCodes.length; i++) {
    const { region, code } = eiaRegionCodes[i];
    const url = eiaURL + eiaSeriesName + code + '-' + eiaUnit + '?api_key=' + apiKey;
    const json = await fetchJson(url);
    if (json && json.response && json.response.data) {
      results.data.datasets.push({
        label: region,
        data: json.response.data.map(d => ({
          x: d.period,
          y: Math.trunc(d.value * 10) / 10
        }))
      });
    }
  };

  // Output results (or save to Redis if Redis Key has been specified)
  const resultsJSON = JSON.stringify(results);
  if (redisKey === undefined) {
    console.log(resultsJSON);
  } else {
    saveToRedis(redisKey, resultsJSON);
  }

})();