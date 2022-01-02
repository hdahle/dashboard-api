// ecdc-csv.js
//
// Turn JHU CSV-files into JSON data and store to Redis
//
// H. Dahle, 2021

var fs = require('fs');
var csv = require('csv-parser');
var redis = require('redis');
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';

let redisKey = argv.key; // redis-key from cmd line
let csvFile = argv.file; // input file

if (redisKey === undefined || redisKey === true || csvFile === undefined || csvFile === true) {
  console.log('Usage:\n\tnode ecdc-csv.js --file <csvfile> --key <rediskey>');
  return;
}

//
// Save to Redis, then quit Redis. On 'end' Redis will terminate this node.js process
//
function redisSave(key, value) {
  console.log(moment().format(momFmt) + ' Store:' + value.length + ' Key=' + key + ' Val=' + value.substring(0, 60));

  var redClient = redis.createClient();
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

//
// Process input-file line-by line
//
// CSV file format:
// country,region_name,nuts_code,year_week,rate_14_day_per_100k,source
// Austria,Burgenland,AT11,2020-13,,Epidemic intelligence subnational data
// Austria,Burgenland,AT11,2020-14,57.7375049246695,Epidemic intelligence subnational data
  let data = [];

  fs.createReadStream(csvFile)
    .pipe(csv(['country','region','c','date','rate']))
    .on('data', columns => {
      // Skip first line in CSV file which is just header info
      if (columns.region === 'region_name') return;
      // find the country in the list
      let c = data.find(d => d.country === columns.country);
      // create new entry in datasets if country does not exist
      if (c === undefined) { 
        // console.log(columns.country)
        c = {
          country: columns.country,
          region: []          
        }
        data.push(c)
      }
      let r = c.region.find(x => x.name === columns.region)
      if (r === undefined) {
        r = {
          name: columns.region,
          data: []
        }
        c.region.push(r);
      }
      // For data>10, just use the integer part. For <10, use one digit after decimalpoint
      let y = (columns.rate<10)?(Math.trunc(10*columns.rate)/10):(Math.trunc(columns.rate))
      r.data.push({
        t: moment(columns.date, 'YYYY-WW').format('YYYYWW'),
        v: y
      })
    })
    .on('end', () => {
       let val = {
        source: '',
        license: '',
        link: '',
        info: '',
        accessed: moment().format('YYYY-MM-DD hh:mm'),
        data: data
      };
      redisSave(redisKey, JSON.stringify(val));
    })
    .on('close', () => {
      console.log('Readstream closed');
    })
    .on('error', err => {
      console.log('Readstream error:', err)
    })
