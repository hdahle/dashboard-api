//
// Read CSV file, Write JSON to Redis
//
// CSV input format:
//   Year, Total, Coal, Oil, Gas, Cement, Flaring, Per Capita,,,,,,,,
//   1959, 2417, 1352, 794, 207, 40, 25, 0.81,,,,,
//   1960, 2550, 1403, 852, 228, 43, 24, 0.84,,,,,
// The JSON should contain time-series data per fuel type.
// So: transpose input data to generate:
// {
//   source: '...',
//   link: '...'
//   data: 
//   [
//     { fuel: 'type', data: [ { x: year, y: value}, ...] },
//     { fuel: 'type', data: [ { x: year, y: value}, ...] },
//   ]
// }
//
// H. Dahle, 2021
//

var fs = require('fs');
var parse = require('csv-parse');
var argv = require('minimist')(process.argv.slice(2), {
  string: ['source', 'link'],
  alias: { f: 'file', s:'source', l:'link', k:'key'}
});

// Redis
var redis = require('redis');
var redClient = redis.createClient();
redClient.on('connect', function () {
});
redClient.on('ready', function () {
});
redClient.on('warning', function () {
  console.log('Redis warning');
});
redClient.on('error', function (err) {
  console.log('Redis error:' + err);
});


(() => {
  let fn = argv.file; // filename from commandline
  let key = argv.key; // redis-key from commandline

  let d = {
    source: argv.source || 'Global Carbon Project, https://www.globalcarbonproject.org/carbonbudget/',
    info: 'Fossil fuel and cement production emissions by fuel type, in million tons of CO2 per country per year',
    link: argv.link || 'https://www.icos-cp.eu/science-and-impact/global-carbon-budget/',
    data: []
  }
  // number of columns in CSV file, for discarding empty columns
  let nCols = 0;

  // see if input-file exists
  if (fn === undefined || fn === true || fn === '' || !fs.existsSync(fn)) {
    console.log('File not found:', fn);
    console.log('Usage: node script --file <filename> [--key <rediskey>] --source "Global Carbon Project etc" --link "hyperlink to source"');
    console.log('Writes JSON to stdout if no --key is specified');
    console.log('Stores JSON to Redis if --key is specified');
    console.log('Also have a look in npm scripts for usage')
    process.exit();
  }

  // Read file and process the CSV file
  fs.createReadStream(fn)
    .pipe(parse({ delimiter: ',' }))
    .on('data', csvRow => {
      if (csvRow[1].includes('Source of')) {
        // add the source information
        // d.source += ' ' + csvRow[1];
      } else if (csvRow[1].includes('Cite as: ')) {
        // additional source information
        // d.source += csvRow[1].replace('Cite as: ', '');
      } else if (csvRow[0] === 'Year') {
        // find first empty column
        nCols = csvRow.length;
        // populate d with fuel types, push data values later
        for (let i = 0; i < nCols - 1; i++) {
          d.data[i] = {
            fuel: csvRow[i + 1].replace('Cement emission', 'Cement').replace('fossil emissions excluding carbonation', 'Total').replace('fossil.emissions.excluding.carbonation', 'Total'),
            data: []
          };
        }
      } else if (!isNaN(csvRow[0]) && csvRow[0] > 1900 && csvRow[0] < 2100) {
        // process the yearly data, 'year' is first element in the row
        // convert from C to CO2 by multiplying by 3.664
        for (let i = 0; i < nCols - 1; i++) {
          d.data[i].data.push({
            x: parseInt(csvRow[0], 10),
            y: Math.floor(csvRow[i + 1] * 366.4) / 100
          });
        }
      }
    })
    .on('end', () => {
      // s is the resulting JSON blob
      let s = JSON.stringify(d);
      // Store to Redis if key is specified
      if (key !== undefined && key !== true && key !== '') {
        redClient.set(key, s, function (error, result) {
          if (result) {
            console.log('Wrote', s.length, 'bytes to Redis key: ' + key);
          }
          else {
            console.log('Error: ' + error);
          }
        });
      } else {
        console.log(s);
      }
      // this is a bit dirty. not sure how to do this properly
      setInterval((() => process.exit()), 500);
    })
    .on('error', err => console.log('ReadStream Error:', err));
})();