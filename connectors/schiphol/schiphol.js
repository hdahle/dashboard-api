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
  console.log(moment().format(momFmt) + ' Redis warning');
});
redClient.on('error', function (err) {
  console.log(moment().format(momFmt) + ' Redis error:' + err);
});

// process commandline
let appID = argv.appID;
let appKey = argv.appKey;
let date = argv.date;
let redisKey = argv.key;

if (appKey === undefined || appID === undefined || date === undefined || redisKey === undefined) {
  console.log('Usage: node script --date <schedule date> --appID <application ID> --appKey <application Key> --key <redis key>');
  process.exit();
}
// If no date given, use today's date
if (date === null) {
  date = moment().format('YYYY-MM-DD');
}
// Make sure it's a valid date otherwise Schiphol returns an error
if (!moment(date, 'YYYY-MM-DD', true).isValid()) {
  console.log('Invalid date');
  console.log('Usage: node script --date <schedule date> --appID <application ID> --appKey <application Key> --key <redis key>');
  process.exit();
}

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
  function flights(results) {
    //console.log('Flights:', results.flights.length);
    results.flights.forEach(x => {
      if (uniqueFlights.includes(x.mainFlight)) {
        //console.log('codeshare', x.flightName);
        return;
      }
      uniqueFlights.push(x.mainFlight);
      console.log(x.mainFlight, 'Scheduled:', x.scheduleDateTime, 'Actual:', x.actualLandingTime)
    });
  }
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
      getFlightDataSingleDay(link);
    } else {
      // No more pages, complete data received
      let s = {
        t: date,
        y: uniqueFlights.length
      }
      // Store key / score to Redis sorted set
      let redisVal = JSON.stringify(s);
      console.log(moment().format(momFmt) + ' Storing ' + redisVal.length + ' bytes, key=' + redisKey + ' val=' + redisVal);
      // Add data to sorted set 'redisKey', using Unix time as sort key
      redClient.zadd(redisKey, moment(date).format('x'), redisVal, function (error, result) {
        if (result) {
          console.log(moment().format(momFmt) + ' Result:' + result);
        } else {
          console.log(moment().format(momFmt) + ' Error: ' + error);
        }
        setTimeout((() => {
          process.exit();
        }), 1000)
      });
    }
    return json;

  } catch (error) {
    console.log(error)
  }
}
getFlightDataSingleDay(url);

// EOF //