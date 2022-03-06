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

var redClient = redis.createClient();
console.log(redClient)
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
redClient.on('end', function () {
  console.log(moment().format(momFmt) + ' Redis closing');
});

let redisKey = argv.key;  // redis-key from cmd line
let ticker = argv.ticker; // stock ticker
let apiKey = argv.apikey; // marketstack API key

if (redisKey === undefined || redisKey === true || apiKey === undefined || apiKey === true || ticker == undefined || ticker == true) {
  console.log('Usage:\n\tnode marketstack.js --ticker <symbol> --apikey <Marketstack API key> --key <Redis Key>');
  return;
}

//
// Save to Redis, then quit Redis
//
function redisSave(key, value) {
  console.log(moment().format(momFmt) + ' Store:' + value.length + ' Key=' + key + ' Val=' + value.substring(0, 60));
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
}

(async () => {
  const url = "https://api.marketstack.com/v1/eod?access_key=" + apiKey + "&symbols=wco2.xfra";
  const response = await fetch(url);
  const data = await response.json();
  let x = {
    source: 'api.marketstack.com',
    accessed: moment().format('YYYY-MM-DD, HH:mm'),
    ticker: data.data[0].symbol,
    exchange: data.data[0].exchange,
    data: []
  };
  data.data.forEach(v => { x.data.push({ x: moment(v.date).format('YYYY-MM-DD'), y: v.close }) });
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
  redisSave(redisKey, JSON.stringify(x));
})();