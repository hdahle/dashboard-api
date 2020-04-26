// schiphol.js
//
// Daily flight statistics Schiphol Airport
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
  console.log(moment().format(momFmt) + ' Redis warning: password set but not needed, or deprecated option etc used');
});
redClient.on('error', function (err) {
  console.log(moment().format(momFmt) + ' Redis error:' + err);
});
redClient.on('end', function (err) {
  console.log(moment().format(momFmt) + ' Redis end: server connection has closed');
});

// process commandline
let appID = argv.appID;
let appKey = argv.appKey;
let date = argv.date;
let redisKey = argv.key;

if (appKey === undefined || appID === undefined || redisKey === undefined) {
  console.log('Usage: node script [--date <schedule date>] --appID <applicationID> --appKey <applicationKey> --key <redisKey>');
  console.log('If no --date is specified, date will default to yesterday');
  console.log('If "--key REDISKEY" is specified:');
  console.log('  REDISKEY-Z : will be used for the sorted set');
  console.log('  REDISKEY : will be used for the entire time-series in JSON format');
  process.exit();
}
// If no date given, use yesterday's date
if (date === undefined) {
  date = moment().add(-1, 'day').format('YYYY-MM-DD');
}
// Make sure it's a valid date otherwise Schiphol returns an error
if (!moment(date, 'YYYY-MM-DD', true).isValid()) {
  console.log('Invalid date');
  console.log('Usage: node script --date <schedule date> --appID <application ID> --appKey <application Key> --key <redis key>');
  process.exit();
}
// Build the request URL and request headers
const url = "https://api.schiphol.nl/public-flights/flights?flightDirection=A"
  + "&fromDateTime=" + moment(date).format('YYYY-MM-DD') + "T00:00:00"
  + "&toDateTime=" + moment(date).format('YYYY-MM-DD') + "T23:59:59"
  + "&searchDateTimeField=actualLandingTime";

const headers = {
  "ResourceVersion": "v4",
  "app_id": appID,
  "accept": "application/json",
  "app_key": appKey
};

let uniqueFlights = [];

async function getFlightDataSingleDay(url) {
  if (url === undefined || url === null) return null;

  // Push all unique flights onto uniqueFlights[]
  function flights(results) {
    results.flights.forEach(x => {
      // do not count code-share flights
      if (!uniqueFlights.includes(x.mainFlight)) {
        uniqueFlights.push(x.mainFlight);
      }
    });
  }

  // Return the 'next' link for pages responses
  function linkUrl(headers) {
    let link = headers.get('Link');
    if (link !== undefined && link !== null) {
      let linkArray = link.split(',');
      while (linkArray.length) {
        let tmp = linkArray.pop().split(';');
        if (tmp[1].includes('rel="next"')) {
          return tmp[0].replace('<', '').replace('>', '')
        }
      }
    }
    return null;
  }

  try {
    const response = await fetch(url, { headers: headers });
    const json = await response.json();
    flights(json);

    // API returns paged data. URL to next page can be found in the response headers
    let link = linkUrl(response.headers);

    if (link) {
      process.stdout.write(link.substr(link.indexOf('page='), link.length) + "\r");
      getFlightDataSingleDay(link);
    } else {
      // No more pages, complete data received
      let s = {
        t: moment(date).format('MM-DD'),
        y: uniqueFlights.length
      }

      // Add data to sorted set 'redisKey-Z', using Unix time as sort key
      let v = JSON.stringify(s);
      let k = redisKey + '-Z';
      console.log(moment().format(momFmt) + ' Redis Z Storing ' + v.length + ' bytes, key=' + k + ' val=' + v);
      redClient.zadd(k, moment(date).format('x'), v, function (error, result) {
        if (result) {
          console.log(moment().format(momFmt) + ' Redis Z Result:' + result);
        } else {
          console.log(moment().format(momFmt) + ' Redis Z Error: ' + error);
        }

        // Read back the entire updated sorted set
        redClient.zrange(k, 0, moment().format('x'), function (error, result) {
          if (result) {
            let val = {
              source: 'Schiphol Airport Developer Center, https://www.schiphol.nl/en/developer-center/',
              accessed: moment().format(momFmt),
              units: 'Flight arrivals per day',
              year: moment(date).format('YYYY'),
              data: []
            };
            for (let i = 0; i < result.length; i++) {
              try {
                val.data.push(JSON.parse(result[i]))
              } catch {
                console.log('Invalid JSON', result[i])
              }
            }

            // Save entire SET as a single entry 
            let v = JSON.stringify(val);
            console.log(moment().format(momFmt) + ' Redis Storing ' + v.length + ' bytes, key=' + redisKey + ' val=' + v);
            redClient.set(redisKey, v, function (error, result) {
              if (result) {
                console.log(moment().format(momFmt) + ' Redis Result:' + result);
              } else {
                console.log(moment().format(momFmt) + ' Redis Error: ' + error);
              }
              setTimeout((() => { process.exit(0) }), 1000);
            });

          } else {
            console.log(moment().format(momFmt) + ' Redis Error: ' + error);
          }
          setTimeout((() => { process.exit(1) }), 1000);
        });
      });
    }
    return json;

  } catch (error) {
    console.log('Schiphol error', error)
    setTimeout((() => { process.exit(1) }), 1000);
  }
}
getFlightDataSingleDay(url);

// EOF //