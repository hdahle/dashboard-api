// vax.js
// Turn JHU CSV-files into JSON data and store to Redis
//
// H. Dahle, 2021

var fs = require('fs');
var parse = require('csv-parse');
var redis = require('redis');
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';
var wp = require('./worldpop.js');

// Parse commandline
const fn = argv.file; 
const redisKey = argv.key; 
const verbose = argv.verbose;
let partial = argv.partial;   // Share of population partially vaccinated
let full = argv.full;         // Share of population fully vaccinated
let doses = argv.doses;       // Number of doses administered
let xy = argv.xy;             // Format data as {date, value} pairs instead of array[dates] array[values]

if (partial === undefined && full === undefined && doses === undefined) {
  partial = true;
  full = true;
  doses = true;
}

let cList = (argv.countries === undefined) ? ['All'] : argv.countries.split(','); // list of countries
let countriesOK = cList.every(x => ['All'].includes(x) || wp.worldPop.findIndex(c => c.c === wp.countryName(x)) > -1);

if (!countriesOK || fn === undefined || fn === true || !fs.existsSync(fn) || redisKey === true || redisKey === '') {
  console.error('Usage:\n\tnode vaccines.js --file <csvfile> [--countries <country,country,...>] [--key <rediskey>] [--partial] [--full] [--doses] [--xy]\n');
  console.error('\t--countries="France,Japan,South Korea" Generate time-series data for the specified countries only');
  console.error('\t    If no countries are specified, then all countries will be used\n');
  console.error('\t--xy       Generate time-series data as {x,y} instead of {labels[],datasets[{data[]}]}');
  console.error('\t--partial  Generate time-series data for partially vaccinated');
  console.error('\t--full     Generate time-series data for fully vaccinated');
  console.error('\t--doses    Generate time-series data for number of doses administered');
  console.error('\t    If none of --partial,--full,--doses are specified, then data for all three will be generated');
  process.exit();
}
if (cList[0] === 'All') {
  cList = wp.worldPop.map(x => x.c);
}
if (verbose) {
  console.log(moment().format(momFmt) + ' Input file:', fn)
  console.log(moment().format(momFmt) + ' Countries:', cList)
  console.log(moment().format(momFmt) + ' Redis key:', redisKey)
}

processFile(fn, cList);

//
// Save to Redis, then quit Redis. On 'end' Redis will terminate this node.js process
//
function redisSave(key, value) {
  let redClient = redis.createClient();
  redClient.on('connect', function () {
    if (verbose) console.log(moment().format(momFmt) + ' Redis client connected');
  });
  redClient.on('ready', function () {
    if (verbose) console.log(moment().format(momFmt) + ' Redis client ready');
    console.log(moment().format(momFmt) + ' Store:' + value.length + ' Key=' + key + ' Val=' + value.substring(0, 60));
    redClient.set(key, value, function (error, result) {
      if (result) {
        console.log(moment().format(momFmt) + ' Result:' + result);
      } else {
        console.error(moment().format(momFmt) + ' Error: ' + error);
      }
      redClient.quit(function () {
        console.log(moment().format(momFmt) + ' Redis quit')
      });
    });
  });
  redClient.on('warning', function () {
    if (verbose) console.log(moment().format(momFmt) + ' Redis warning');
  });
  redClient.on('error', function (err) {
    if (verbose) console.log(moment().format(momFmt) + ' Redis error:' + err);
  });
  redClient.on('end', function () {
    if (verbose) console.log(moment().format(momFmt) + ' Redis closing');
    process.exit();
  });
}

//
// Process input-file line-by line
// CSV input columns:
// Country_Region,Date,Doses_admin,People_partially_vaccinated,People_fully_vaccinated,Report_Date_String,UID,Province_State
//
function processFile(fn, cList) {
  let result = [];
  let firstLineFound = false;

  fs.createReadStream(fn)
    .pipe(parse({ delimiter: ',' }))
    .on('data', csv => {
      // This is the first line in the CSV file
      if (csv[0] === 'Country_Region') {
        firstLineFound = true;
        return;
      }
      // Skip this, we already have US
      if (csv[0] === 'US (Aggregate)') {
        return;
      }
      // Skip regions, they are included in country data
      if (csv[7].length > 0) {
        return;
      }
      // Now process each line of country-data
      let cName = wp.countryName(csv[0]);
      let country = wp.worldPop.find(x => x.c === cName);
      if (country === undefined) {
        console.error('Warning: Undefined country, skipping', cName);
        return;
      }
      // Only process countries specified in cList
      if (!cList.find(x => x === country.c)) {
        return;
      }
      // Does country already exist in result? If not, push new country     
      let a = result.find(x => x.country == country.c);
      if (a === undefined) {
        a = {
          country: country.c,
          region: country.r,
          data: {
            datasets: []
          }
        }
        if (!xy) a.data.labels = [];
        if (partial) a.data.datasets.push({ label: "Partial", data: [] })
        if (full) a.data.datasets.push({ label: "Full", data: [] })
        if (doses) a.data.datasets.push({ label: "Doses", data: [] })
        result.push(a)
      }
      if (xy) {
        if (partial) a.data.datasets[0].data.push({ x:csv[1], y:Math.trunc(1000 * csv[3] / country.p) / 10 });
        if (full) a.data.datasets[1].data.push({ x:csv[1], y:Math.trunc(1000 * csv[4] / country.p) / 10 });
        if (doses) a.data.datasets[2].data.push({ x:csv[1], y:parseInt(csv[2], 10) });  
      } else {
        a.data.labels.push(csv[1]);
        if (partial) a.data.datasets[0].data.push(Math.trunc(1000 * csv[3] / country.p) / 10);
        if (full) a.data.datasets[1].data.push(Math.trunc(1000 * csv[4] / country.p) / 10);
        if (doses) a.data.datasets[2].data.push(parseInt(csv[2], 10));  
      }
    })
    .on('end', () => {
      if (verbose) console.log('Number of countries:', result.length)
      if (!firstLineFound) {
        console.error('Error: First line in file not found');
        return;
      }
      let val = {
        source: 'Johns Hopkins University, https://github.com/govex/COVID-19',
        link: 'https://github.com/govex/COVID-19/blob/master/data_tables/vaccine_data/global_data/time_series_covid19_vaccine_global.csv',
        info: 'Three datasets per country: [0] Partially vaccinated, [1] Fully vaccinated, [2] Total number of doses administered',
        accessed: moment().format('YYYY-MM-DD hh:mm'),
        numberOfCountries: result.length,
        data: result
      };
      // Store resulting JSON to redis or print to stdout
      if (redisKey === undefined) {
        console.log(JSON.stringify(val));
      } else {
        redisSave(redisKey, JSON.stringify(val));
      }
    })
    .on('close', () => {
      console.log('Readstream closed');
    })
    .on('error', err => {
      console.error('Readstream error:', err)
    })
}



