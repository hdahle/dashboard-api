// traffic.js
//
// Read JSON from www.vegvesen.no, simplify, store to Redis
//
// H. Dahle, 2020

var fetch = require('node-fetch');
var redis = require('redis');
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';
const url = 'https://www.vegvesen.no/trafikkdata/api/';

main();

function main() {
  let year = argv.year; // year
  let stationID = argv.station; // traffic station
  let redisKey = argv.key; // redis-key from cmd line
  if (redisKey === undefined || redisKey === true || redisKey === '' || year < 2000 || year > 2020) {
    console.log('Usage: node script --year <year> --station <stationID> --key <rediskey>');
    return;
  }
  var redClient = redis.createClient();
  redClient.on('connect', function () {
    console.log(moment().format(momFmt) + ' Redis client connected');
  });
  redClient.on('ready', function () {
    console.log(moment().format(momFmt) + ' Redis client ready');
    processFile(year, stationID, redisKey, redClient);
  });
  redClient.on('warning', function () {
    console.log(moment().format(momFmt) + ' Redis warning');
  });
  redClient.on('error', function (err) {
    console.log(moment().format(momFmt) + ' Redis error:' + err);
  });
}

function processFile(year, stationID, redisKey, redClient) {
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

  // We will grab 99 days of data, 90 days before today and 9 days after
  let yearDiff = parseInt(year, 10) - parseInt(moment().format('YYYY'), 10);
  let fromDate = moment().add(yearDiff, 'y').add(-90, 'd').format('YYYY-MM-DD');
  let days = 99;
  // If we are getting data for current year, then do not ask for data today or future
  if (yearDiff === 0) {
    days = 90;
  }
  let toDate = moment(fromDate).add(days, 'd').format('YYYY-MM-DD');

  // This is a GraphQL query 
  fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      query: '{ trafficData(trafficRegistrationPointId: \"' + stationID + '\") ' +
        '{ volume ' +
        '{ byDay(from: \"' + fromDate + 'T00:00:00+02:00\", to: \"' + toDate + 'T00:00:00+02:00\")' +
        '{ edges' +
        '{ node' +
        '{ from to total' +
        '{ volumeNumbers' +
        '{ volume }}}}}}}}"'
    })
  })
    .then(status)
    .then(json)
    .then(res => {
      if (res.data === null || res.data.trafficData.volume.byDay.edges === 0) {
        console.log(moment().format(momFmt) + ' Error: No data, aborting')
        process.exit();
      }

      // time-data is in YYYY-MM-DDTHH:MM+02:00 format
      // we want to simplify to MM-DD
      // however we need to stay in the same timezone, so we use moment.parseZone()
      let d = res.data.trafficData.volume.byDay.edges.map(e => ({
        t: moment.parseZone(e.node.from).format('MM-DD'),
        y: e.node.total.volumeNumbers ? e.node.total.volumeNumbers.volume : null
      }));

      let tmp = 0;
      d.forEach(x => { if (x.y === null) tmp++ });
      console.log(moment().format(momFmt) + ' Data:', d.length, 'Null data:', tmp)

      let val = JSON.stringify({
        source: 'Statens Vegvesen / Norwegian Public Roads Administration',
        license: 'Norwegian Licence for Open Government Data (NLOD). You are allowed to: copy and distribute data, modify data and/ or combine data with other data sets, copy and distribute such changed or combined data, use the data commercially.',
        link: 'https://www.vegvesen.no/trafikkdata/api',
        updated: moment().format(momFmt),
        year: year,
        station: stationID,
        data: d
      });

      console.log(moment().format(momFmt) + ' Store:' + val.length + ' Key=' + redisKey + ' Val=' + val.substring(0, 100));

      // Store key/value pair to Redis
      redClient.set(redisKey, val, function (error, result) {
        if (result) {
          console.log(moment().format(momFmt) + ' Result:' + result);
        } else {
          console.log(moment().format(momFmt) + ' Error: ' + error);
        }
        setTimeout(() => { process.exit(); }, 1000); // We are done
      });
    })
    .catch(err => {
      console.log(err)
    });
}
