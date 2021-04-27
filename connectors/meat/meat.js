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
var argv = require('minimist')(process.argv.slice(2), {
  string: ['key', 'url'],
  alias: { y: 'year', k: 'key', u: 'url' }
});
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

// Fetch OECD data
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
  const redisKey = argv.key;  // redis-key from cmd line
  const year = argv.year || 2019;   // end date
  const url = argv.url || 'https://api.dashboard.eco/oecd-meat-2020';

  if (redisKey === undefined) {
    console.log('Usage: node meat.js --key <rediskey> [--year <year>] [--url <url>]');
    process.exit();
  }

  console.log(moment().format(momFmt) + ' Fetching ' + url);
  fetch(url)
    .then(status)
    .then(json)
    .then(results => {
      // results.data is undefined if incorrect query URL
      if (!results || (results.data === undefined) || (results.data.length === 0)) {
        console.log(moment().format(momFmt) + 'No data from url:', url, results);
        process.exit();
      }
      let labels = []; // list of countries
      let datasets = [];
      ["Sheep", "Beef", "Pork", "Poultry"].forEach(x => {
        datasets.push({
          label: x,
          data: []
        })
      });

      results.data.forEach(country => {
        labels.push(country.country);
        country.datasets.forEach(d => {
          let value = d.data.find(x => x.x === year);
          let dataset = datasets.find(dset => dset.label === d.label);
          if (value === undefined || dataset === undefined || value.y === undefined) return;
          dataset.data.push(value.y);
        });
      });

      // Create the "Totals" dataset
      let totals = datasets[0].data.slice();
      for (let i = 1; i < datasets.length; i++) {
        for (let j = 0; j < totals.length; j++) {
          totals[j] += datasets[i].data[j];
        }
      }

      let sorted = [];
      for (let i = 0; i < totals.length; i++) {
        sorted.push({
          country: labels[i],
          total: totals[i],
          sheep: datasets[0].data[i],
          beef: datasets[1].data[i],
          pork: datasets[2].data[i],
          poultry: datasets[3].data[i],
        })
      }
      sorted.sort((a, b) => b.total - a.total)

      // Store key/value pair to Redis
      let redisValue = JSON.stringify({
        source: results.source,
        link: results.link,
        license: results.license,
        accessed: results.accessed,
        year: year,
        data: {
          labels: sorted.map(x => x.country),
          datasets: [{
            label: "Sheep",
            data: sorted.map(x => x.sheep)
          }, {
            label: "Beef",
            data: sorted.map(x => x.beef)
          }, {
            label: "Pork",
            data: sorted.map(x => x.pork)
          }, {
            label: "Poultry",
            data: sorted.map(x => x.poultry)
          }]
        }
      });
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
    .catch(err => {
      console.log(err.message);
      process.exit();
    })
})();