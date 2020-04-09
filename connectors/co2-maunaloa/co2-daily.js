//
//
//
// Håkon Dahle, 2020

var fs = require('fs');
var redis = require('redis');
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';
var readline = require('readline');

console.log(moment().format(momFmt), 'co2-daily');
let fn = argv.file; // filename from cmd line
let redisKey = argv.key; // redis-key from cmd line
if (fn === undefined || fn === true || redisKey === undefined || redisKey === true || redisKey === '') {
  console.log('Usage: node script --file <filename> --key <rediskey>');
  return;
}

var redClient = redis.createClient();
redClient.on('connect', function () {
  console.log(moment().format(momFmt) + ' Redis client connected');
});
redClient.on('ready', function () {
  console.log(moment().format(momFmt) + ' Redis client ready');
  processFile(fn, redisKey);
});
redClient.on('warning', function () {
  console.log(moment().format(momFmt) + ' Redis warning');
});
redClient.on('error', function (err) {
  console.log(moment().format(momFmt) + ' Redis error:' + err);
});

function processFile(fn, key) {
  let timeSeries = [];
  const readInterface = readline.createInterface({
    input: fs.createReadStream(fn),
    console: false
  });
  // Process a line of text, save to timeSeries[]
  readInterface.on('line', (line) => {
    let res = processLine(line);
    if (res === null) return;
    timeSeries.push(res);
  });
  // Convert result to string, save to Redis
  readInterface.on('close', () => {
    let json = processCsvEnd(timeSeries);
    let val = JSON.stringify(json);
    console.log(moment().format(momFmt) + ' Store:' + val.length + ' Key=' + key + ' Val=' + val.substring(0, 100));
    redClient.set(key, val, function (error, result) {
      if (result) {
        console.log(moment().format(momFmt) + ' Result:' + result);
      } else {
        console.log(moment().format(momFmt) + ' Error: ' + error);
      }
      setTimeout(() => { process.exit(); }, 2000); // We are done
    });
  });
  // This error handling is excellent
  readInterface.on('error', (err) => {
    console.log('error:', err);
  });
}

// Verify and process a line. Thers is one line per day
function processLine(csv) {
  let s = csv.split(/[ ]+/);
  // Remove empty fields, often occurs at beginning of line
  s = s.filter(x => !isNaN(parseFloat(x)));
  // Sanity check the input line, should be exactly 5 fields
  // Y M D float float
  if (s.length !== 5) return null;
  if (s[0] < 1900 || s[0] > moment().format('YYYY')) return null;
  if (s[1] < 1 || s[1] > 12) return null;
  if (s[2] < 1 || s[2] > 31) return null;
  return {
    t: moment(s[0] + '-' + s[1] + '-' + s[2], 'YYYY-M-D').format('YYYYMMDD'),
    y: parseFloat(s[3])
  };
}

// When finished processing, create JSON datastructure
// This should be the result:
// [ 
//   { year: 2010, data: [ {t:MM-DD, y:float}, {}, ... ] }
//   { year: 2011, data: [ {t:MM-DD, y:float}, {}, ... ] }
// ]
// This structure should make client-side processing very easy
function processCsvEnd(timeSeries) {
  // create list of years
  let unique = [];
  let years = timeSeries.map(x => moment(x.t).format('YYYY'));
  while (years.length) {
    let y = years.pop();
    if (unique.includes(y)) continue;
    unique.push(y);
  }
  // unique[] is now list of years
  // now create one data array per year
  let d = [];
  while (unique.length) {
    let y = unique.shift();
    let data = timeSeries.filter(x => y == moment(x.t).format('YYYY'));
    data = data.map(x => ({
      t: moment(x.t).format('MM-DD'),
      y: x.y
    }));
    d.push({
      year: y,
      data: data
    });
  }
  return {
    source: 'Dr. Pieter Tans, NOAA/ESRL (www.esrl.noaa.gov/gmd/ccgg/trends/) and Dr. Ralph Keeling, Scripps Institution of Oceanography (scrippsco2.ucsd.edu)',
    license: 'From https://www.esrl.noaa.gov/gmd/about/disclaimer.html: The information on government servers are in the public domain, unless specifically annotated otherwise, and may be used freely by the public so long as you do not 1) claim it is your own (e.g. by claiming copyright for NOAA information – see next paragraph), 2) use it in a manner that implies an endorsement or affiliation with NOAA, or 3) modify it in content and then present it as official government material. You also cannot present information of your own in a way that makes it appear to be official government information. Please provide acknowledgement of the NOAA ESRL Global Monitoring Division in use of any of our web products as: Data / Image provided by NOAA ESRL Global Monitoring Division, Boulder, Colorado, USA(http://esrl.noaa.gov/gmd/)',
    link: 'ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_trend_gl.txt',
    info: 'Daily atmospheric CO2 values measured at the Mauna Loa Observatory',
    accessed: moment().format(momFmt),
    data: d
  };
}

// Exports for Mocha/Chai Testing
module.exports.processLine = processLine;
