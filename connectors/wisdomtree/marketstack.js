// marketstack.js
//
// Get Shareprices from Marketstack
//
// H. Dahle, 2022

var fetch = require('node-fetch');
var redis = require('redis');
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';

//
// Save to Redis, then quit Redis
//
function redisSave(key, value) {
  console.log(moment().format(momFmt) + ' Store:' + value.length + ' Key=' + key + ' Val=' + value.substring(0, 60));
  let redClient = redis.createClient();
  redClient.on('connect', function () {
    console.log(moment().format(momFmt) + ' Redis client connected');
  });
  redClient.on('ready', function () {
    console.log(moment().format(momFmt) + ' Redis client ready');
    redClient.set(key, value, function (error, result) {
      if (result) {
        console.log(moment().format(momFmt) + ' Result:' + result);
      } else {
        console.log(moment().format(momFmt) + ' Error: ' + error);
      }
      redClient.quit(function () {
        console.log(moment().format(momFmt) + ' Redis quit')
      });
    });
  });
  redClient.on('warning', function () {
    console.log(moment().format(momFmt) + ' Redis warning');
  });
  redClient.on('error', function (err) {
    console.log(moment().format(momFmt) + ' Redis error:' + err);
  });
  redClient.on('end', function () {
    console.log(moment().format(momFmt) + ' Redis closing');
  });
}

(async () => {
  const redisKey = argv.key;    // redis-key from cmd line
  const ticker = argv.ticker;   // stock ticker
  const apiKey = argv.apikey;   // marketstack API key
  const verbose = argv.verbose;
  let limit = argv.limit;     // number of quotes per page, max 1000

  if (redisKey === true || apiKey === undefined || apiKey === true || ticker == undefined || ticker == true) {
    console.log('Usage:\n\tnode marketstack.js --ticker <symbol> --apikey <Marketstack API key> [--key <Redis Key>] [--verbose]');
    console.log('  --key <Redis Key>  Store resulting JSON to Redis. If --key is not used, output to STDOUT');
    console.log('  --verbose          Lots of unnecessary data');
    console.log('  --ticker <symbol>  Something like wco2.xfra or aapl.xnas or pexip.xosl');
    console.log('  --limit <days>     Number of quotes per page, max 1000, default 100');
    return;
  }

  if (Number.isInteger(limit) === false || limit > 1000 || limit < 1) {
    limit = 100;
  }

  const url = "https://api.marketstack.com/v1/eod?access_key=" + apiKey + "&symbols=" + ticker + "&limit=" + limit;
  const response = await fetch(url);
  const data = await response.json();
  let x = {
    source: 'api.marketstack.com',
    accessed: moment().format('YYYY-MM-DD, HH:mm'),
    data: []
  };
  if (data.data !== undefined && Array.isArray(data.data)) {
    x.ticker = data.data[0].symbol;
    x.exchange = data.data[0].exchange;
    if (verbose) {
      x.data = data.data;
    } else {
      data.data.forEach(v => { x.data.push({ x: moment(v.date).format('YYYY-MM-DD'), y: v.close }) });
    }
  }
  /* The returned data looks thus and we will simplify it before storing to Redis: 
    {
      pagination: { limit: 100, offset: 0, count: 79, total: 79 },
      data: [
        {
          open: 29.068,
          high: 29.068,
          low: 27.832,
          close: 27.832,
          volume: 1713,
          adj_high: null,
          adj_low: null,
          adj_close: 27.832,
          adj_open: null,
          adj_volume: null,
          split_factor: 1,
          dividend: 0,
          symbol: 'WCO2.XFRA',
          exchange: 'XFRA',
          date: '2022-02-28T00:00:00+0000'
        },
        {},...,{}
      ]
    }
    */
  if (redisKey === undefined) {
    console.log(JSON.stringify(x))
  } else {
    redisSave(redisKey, JSON.stringify(x));
  }
})();