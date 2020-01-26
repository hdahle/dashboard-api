//
// Read CSV file, Write JSON to Redis
//
// H. Dahle, 2020
//

var fs = require('fs');
var parse = require('csv-parse');
var argv = require('minimist')(process.argv.slice(2));
var redis = require('redis');
var redClient = redis.createClient();
var moment = require('moment');
const momFmt = 'YY-MM-DD hh:mm:ss';

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

processCSV();

function processCSV() {
  // process the command line, filename and redis key expected
  // if no Redis key, we will just output to console.log
  let fn = argv.file;
  let key = argv.key;
  let c = argv.countries;
  let cList = [];
  // this is the JSON we will store to Redis
  let d = {
    source: '',
    info: 'Fossil fuels and cement production emissions by country, in million tons of CO2 per country per year',
    nCountries: '',
    countries: [],
    data: []
  }

  // create country-subset list and sort it
  if (c !== undefined && c !== true && c.length) {
    cList = c.split(',');
    cList.sort();
  }

  // see if input-file exists
  if (fn === undefined || fn === true || fn === '' || !fs.existsSync(fn)) {
    console.log('File not found:', fn);
    process.exit();
  }
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
        d.countries = csvRow;
        d.nCountries = csvRow.length;
      } else {
        // process the yearly data, 'year' is first element in the row
        let y = csvRow.shift();
        // skip any empty rows
        if (y.length && (y > 1700) && (y < 2100)) {
          // note that CSV files contain some cells with the string 'NaN'
          // we will just use 0 instead of these 'NaN's
          // multiply all values by 3.664 to convert from C to CO2
          let v = csvRow.map(x => x === "NaN" ? 0 : Math.floor(x * 366.4) / 100);
          d.data.push({
            year: y,
            records: v.length,
            data: v
          });
        }
      }
    })
    .on('end', () => {
      let s = '';
      if (cList.length) {
        // Build list of indices into d.countries[]
        let idx = [];
        for (let i = 0; i < cList.length; i++) {
          let tmp;
          idx.push((tmp = d.countries.findIndex(s => s === cList[i])));
          if (tmp === -1) {
            console.log('Error: country not found:', cList[i]);
            process.exit();
          }
        }
        let data = [];

        for (let i = 0; i < d.data.length; i++) {
          let res = [];
          for (let j = 0; j < d.data[i].data.length; j++) {
            if (idx.includes(j)) {
              res.push(d.data[i].data[j])
            }
          }
          data.push({
            year: d.data[i].year,
            records: res.length,
            data: res
          });
        }
        d.data = data;
        d.countries = cList;
        d.nCountries = cList.length;
      }
      s = JSON.stringify(d);
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
}
