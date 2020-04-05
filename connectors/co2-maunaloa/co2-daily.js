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
    console.log(moment().format(momFmt) + ' Store:' + val.length + ' Key=' + key + ' Val=' + val);//.substring(0, 100));
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
function processCsvEnd(timeSeries) {
  return {
    source: '""',
    license: '""',
    link: '""',
    info: '"Daily atmospheric CO2 values measured at the Mauna Loa Observatory"',
    updated: moment().format(momFmt),
    data: timeSeries
  };
}

// Exports for Mocha/Chai Testing
module.exports.processLine = processLine;
