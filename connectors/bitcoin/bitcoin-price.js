// bitcoin-price.js
//
// Fetches Bitcoin price from api.coindesk.com
// Converts original JSON to plot-friendly JSON
// Store to Redis
//
// H. Dahle, 2021

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

// Fetch Bitcoin data
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
  let redisKey = argv.key;  // redis-key from cmd line
  let endDate = argv.end;   // end date
  let startDate = argv.start; // start date

  if (redisKey === undefined) {
    console.log('Usage: node bitcoin-price.js --key <rediskey>');
    process.exit();
  }

  // build a single query URL, include all regions
  const dateToday = moment().format('YYYY-MM-DD')
  let url = 'https://api.coindesk.com/v1/bpi/historical/close.json?start=2015-01-01&end=' + dateToday;

  fetch(url)
    .then(status)
    .then(json)
    .then(results => {
      // results.series is undefined if incorrect query URL
      if (results.bpi === undefined) {
        console.log('No data from api.coindesk.com: ', results, url);
        process.exit();
      }

      // original coindesk.com data is:   {bpi:{ "yyyy-mm-dd":nnnn, "yyyy-mm-dd":nnnn, ...  }}
      let json = {
        source: 'Bitcoin price data is Powered by CoinDesk',
        link: 'https://www.coindesk.com/price/bitcoin',
        license: 'From the Coindesk website: You are free to use this API to include our data in any application or website as you see fit, as long as each page or app that uses it includes the text “Powered by CoinDesk”, linking to our price page. ',
        accessed: moment().format(),
        data: {
          datasets: [
            {
              label: 'Bitcoin price, USD',
              data: Object.entries(results.bpi).map(x => ({ t: x[0], y: Math.floor(x[1]) }))
            }
          ]
        }
      };

      // Store key/value pair to Redis
      let redisValue = JSON.stringify(json);
      console.log(moment().format(momFmt) +
        ' Bytes=' + redisValue.length +
        ' Array length=' + json.data.length +
        ' Redis key=' + redisKey +
        ' Value=' + redisValue.substring(0, 60));

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

