//
// Read CSV file, Write JSON to Redis
//
// March 2, 2021: Change output values to Gigatons
// H. Dahle, 2021
//

// CSV input format:
//  ,(4) The statistical difference presented on column HX is the 
//  MtC/yr,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
//  ,AFGHANISTAN,ALBANIA,ALGERIA,ANDORRA,ANGOLA,ANGUILLA,ANTIGUA,....
//  ,Afghanistan,Albania,Algeria,Andorra,Angola,Anguilla,Antigua,....
//  1959,0,0,2,NaN,0,NaN,0,13,2,0,23,8,5,0,0,1,0,12,24,0,0,0,NaN,....
//  1960,0,1,2,NaN,0,NaN,0,13,2,0,24,8,6,0,0,1,0,12,25,0,0,0,NaN,....
//
// Must transpose input data to generate:
// {
//   source: '...',
//   link: '...'
//   data: 
//   [
//     { country: 'name', data: [ { x: year, y: value}, ...] },
//     { country: 'name', data: [ { x: year, y: value}, ...] },
//   ]
// }
//

var fs = require('fs');
var parse = require('csv-parse');
var argv = require('minimist')(process.argv.slice(2));

var moment = require('moment');
const momFmt = 'YY-MM-DD hh:mm:ss';

// Redis stuff
var redis = require('redis');
var redClient = redis.createClient();
redClient.on('connect', function () {
});
redClient.on('ready', function () {
});
redClient.on('warning', function () {
  console.log(moment().format(momFmt) + ' Redis warning');
});
redClient.on('error', function (err) {
  console.log(moment().format(momFmt) + ' Redis error:' + err);
});

(() => {
  let fn = argv.file; // filename from cmd line
  let key = argv.key; // redis-key from cmd line
  let c = argv.countries; // optional country-list from cmd-line
  let cList = [];

  let d = {
    source: 'Global Carbon Project December 2020, https://www.globalcarbonproject.org/carbonbudget/',
    info: 'Fossil fuels and cement production emissions by country, in billion tons (Gt, gigatons) of CO2 per country per year',
    link: 'https://www.globalcarbonproject.org',
    data: {
      yAxisLabel: 'Gt',
      datasets: []
    }
  }
  // number of countries/entries per line/row
  let nCols = 0;

  // see if input-file exists
  if (fn === undefined || fn === true || fn === '' || !fs.existsSync(fn)) {
    console.log('File not found:', fn);
    console.log('Usage: node script --file <filename> [--countries <countries>] [--key <rediskey>]');
    console.log('Writes JSON to stdout if no --key is specified');
    console.log('Stores JSON to Redis if --key is specified');
    console.log('If --countries is not used, will generate a full list of countries');
    console.log('Using --countries: --countries "Norway,Sweden,USA,Canada,Saudi Arabia"');
    console.log('Using --countries: --countries Regions');
    console.log('Using --countries: --countries G20');
    process.exit();
  }


  // create country-subset list
  if (c !== undefined && c !== true && c.length) {
    cList = c.toLowerCase().split(',');
  }

  if (cList.length === 1) {
    if (cList[0] === 'g20') {
      cList = [
        'argentina', 'australia', 'brazil', 'canada', 'china', 'france', 'germany', 'india',
        'indonesia', 'italy', 'japan', 'south korea', 'united kingdom', 'mexico',
        'russian federation', 'saudi arabia', 'south africa', 'turkey', 'usa', 'eu28'
      ];
    }
    if (cList[0] === 'regions') {
      cList = [
        'africa', 'asia', 'bunkers', 'central america', 'north america',
        'south america', 'europe', 'middle east', 'oceania', 'world'
      ];
    }
  }
  // cList.forEach(x => { x = x.toLowerCase });

  // process the CSV file
  fs.createReadStream(fn)
    .pipe(parse({ delimiter: ',' }))
    .on('data', csvRow => {
      if (csvRow[1].includes('Source of')) {
        // add the source information
        d.source += ' ' + csvRow[1];
      } else if (csvRow[1].includes('Cite as: ')) {
        // additional source information
        d.source += csvRow[1].replace('Cite as: ', '') + ' / ';
      } else if (csvRow[1] === 'Afghanistan') {
        // get the list of countries, row starts w empty element
        csvRow.shift();
        nCols = csvRow.length;//indexOf('');
        for (let i = 0; i < nCols; i++) {
          d.data.datasets[i] = {
            label: csvRow[i],
            data: []
          };
        }
      } else if (csvRow[0] > 1900 && csvRow[0] < 2100) {
        // process the yearly data, 'year' is first element in the row
        // multiply all values by 3.664 to convert from C to CO2
        let year = csvRow.shift();
        if (isNaN(year)) {
          console.log("Error: Year is NaN:", csvRow)
        }

        for (let i = 0; i < nCols; i++) {
          let y = csvRow[i];
          if (isNaN(y)) y = 0;

          d.data.datasets[i].data.push({
            x: parseInt(year, 10), // avoid quotemarks around year
            y: Math.floor(y * 366.4 / 1000) / 100
          });
        }
      }
    })
    .on('end', () => {
      // if we have specified some countries, remove all other countries from result
      if (cList.length) {
        d.data.datasets = d.data.datasets.filter(x => cList.includes(x.label.toLowerCase()));
      }

      d.data.datasets.forEach(x => {
        x.label = x.label.replace('Central', 'C');
        x.label = x.label.replace('North', 'N');
        x.label = x.label.replace('South', 'S');
        x.label = x.label.replace('Bunkers', 'Transport');
      });

      let s = JSON.stringify(d);
      // Store to Redis is key is specified
      if (key !== undefined && key !== true && key !== '') {
        redClient.set(key, s, function (error, result) {
          if (result) {
            console.log(moment().format(momFmt), 'Wrote', s.length, 'bytes to Redis key: ' + key);
          }
          else {
            console.log(moment().format(momFmt) + ' Error: ' + error);
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
