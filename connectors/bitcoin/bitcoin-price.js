// bitcoin-price.js
//
// Fetches Bitcoin price from api.coindesk.com
// Converts original JSON to plot-friendly JSON
// Store to Redis
//
// H. Dahle, 2021

var fetch = require('node-fetch');

var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';

function redisSave(redisKey, redisValue) {
  let redis = require('redis');
  let redClient = redis.createClient();
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
  console.log(moment().format(momFmt) +
    ' Bytes=' + redisValue.length +
    ' Redis key=' + redisKey +
    ' Value=' + redisValue.substring(0, 60));
  redClient.set(redisKey, redisValue, function (error, result) {
    if (result) {
      console.log(moment().format(momFmt) + ' Result:' + result);
    } else {
      console.log(moment().format(momFmt) + ' Error: ' + error);
    }
    redClient.quit(function () {
      console.log(moment().format(momFmt) + ' Redis quit');
    });
  });
}

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

  const redisKey = argv.key;  // redis-key from cmd line
  const help = argv.help;
  if (help || redisKey == true) {
    console.log('Fetch daily Bitcoin price data from 5 years ago until today');
    console.log('Uses data from api.coindesk.com');
    console.log('Usage: node bitcoin-price.js --key <rediskey>');
    process.exit();
  }

  // build a single query URL, include all regions
  const dateToday = moment().format('YYYY-MM-DD');
  const dateFiveYearsAgo = moment().add(-5, 'years').format('YYYY-MM-DD');
  const url = 'https://api.coindesk.com/v1/bpi/historical/close.json?start=' + dateFiveYearsAgo + '&end=' + dateToday;

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
      const json = {
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

      // If redisKey defined store key/value pair to Redis. If not,just print to console
      const redisValue = JSON.stringify(json);
      if (redisKey) {
        redisSave(redisKey, redisValue);
      } else {
        console.log(redisValue)
      }
    })
    .catch(err => console.log(err))
})();

