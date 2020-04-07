//
// Store power generation stats from Spain into Redis
//
// Håkon Dahle, 2020

var fetch = require('node-fetch');
var redis = require('redis');
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';

console.log(moment().format(momFmt), 'spain-electricity');
let year = argv.year; // filename from cmd line
let redisKey = argv.key; // redis-key from cmd line
if (year === undefined || year === true || redisKey === undefined || redisKey === true || redisKey === '') {
  console.log('Usage: node script --year <2000...2020> --key <rediskey>');
  return;
}

if (year < 2000 || year > Number(moment().format('YYYY'))) {
  console.log('Usage: node script --year <2000...2020> --key <rediskey>');
  return;
}

let url = 'https://apidatos.ree.es/en/datos/demanda/evolucion?start_date='
  + year + '-01-01&end_date='
  + (1 + year) + '-01-01&time_trunc=day';

var redClient = redis.createClient();
redClient.on('connect', function () {
  console.log(moment().format(momFmt) + ' Redis client connected');
});
redClient.on('ready', function () {
  console.log(moment().format(momFmt) + ' Redis client ready');
  processFile(url, redisKey);
});
redClient.on('warning', function () {
  console.log(moment().format(momFmt) + ' Redis warning');
});
redClient.on('error', function (err) {
  console.log(moment().format(momFmt) + ' Redis error:' + err);
});

function processFile(url, key) {
  console.log(moment().format(momFmt), url, key);
  function status(response) {
    if (response.status >= 200 && response.status < 300) {
      return Promise.resolve(response)
    } else {
      console.log(response)
      return Promise.reject(new Error(response.statusText))
    }
  }
  function json(response) {
    return response.json()
  }
  fetch(url)
    .then(status)
    .then(json)
    .then(results => {
      let d = results.included[0].attributes.values;
      if (d === undefined) {
        return;
      }
      console.log(moment().format(momFmt) + ' Records:' + d.length);
      let year = moment(d[0].datetime).format('YYYY');
      d = d.map(x => ({
        t: moment(x.datetime).format('YYYY-MM-DD'),
        y: x.value
      }))

      let val = JSON.stringify({
        source: 'Red Electrica de Espana, https://ree.es/en',
        link: 'https://apidatos.ree.es',
        info: 'Daily electricity demand in Spain',
        updated: moment().format(momFmt),
        year: year,
        data: d
      });

      console.log(moment().format(momFmt) + ' Store:' + val.length + ' Key=' + key + ' Val=' + val.substring(0, 100));

      redClient.set(key, val, function (error, result) {
        if (result) {
          console.log(moment().format(momFmt) + ' Result:' + result);
        } else {
          console.log(moment().format(momFmt) + ' Error: ' + error);
        }
        setTimeout(() => { process.exit(); }, 2000); // We are done
      });

    })
    .catch(err => console.log(err));
}

