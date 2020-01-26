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
  // this is the JSON we will store to Redis
  let d = {
    source: 'Reference of the full global carbon budget 2019: Pierre Friedlingstein, Matthew W. Jones, Michael O’Sullivan, Robbie M. Andrew, Judith Hauck, Glen P. Peters, Wouter Peters, Julia Pongratz, Stephen Sitch, Corinne Le Quéré, Dorothee C. E. Bakker, Josep G. Canadell, Philippe Ciais, Rob Jackson, Peter  Anthoni, Leticia Barbero, Ana Bastos, Vladislav Bastrikov, Meike Becker, Laurent Bopp, Erik Buitenhuis, Naveen Chandra, Frédéric Chevallier, Louise P. Chini, Kim I. Currie, Richard A. Feely, Marion Gehlen, Dennis Gilfillan, Thanos Gkritzalis, Daniel S. Goll, Nicolas Gruber, Sören Gutekunst, Ian Harris, Vanessa Haverd, Richard A. Houghton, George Hurtt, Tatiana Ilyina, Atul K. Jain, Emilie Joetzjer, Jed O. Kaplan, Etsushi Kato, Kees Klein Goldewijk, Jan Ivar Korsbakken, Peter Landschützer, Siv K. Lauvset, Nathalie Lefèvre, Andrew Lenton, Sebastian Lienert, Danica Lombardozzi, Gregg Marland, Patrick C. McGuire, Joe R. Melton, Nicolas Metzl, David R. Munro, Julia E. M. S. Nabel, Shin-Ichiro Nakaoka, Craig Neill, Abdirahman M. Omar, Tsuneo Ono, Anna Peregon, Denis Pierrot, Benjamin Poulter, Gregor Rehder, Laure Resplandy, Eddy Robertson, Christian Rödenbeck, Roland Séférian, Jörg Schwinger, Naomi Smith, Pieter P. Tans, Hanqin Tian, Bronte Tilbrook, Francesco N Tubiello, Guido R. van der Werf, Andrew J. Wiltshire, Sönke Zaehle. Global Carbon Budget 2019, Earth Syst. Sci. Data, 2019. https://doi.org/10.5194/essd-11-1783-2019 ',
    info: 'Fossil fuel and cement production emissions by fuel type, in million tons of CO2 per country per year',
    link: 'https://www.icos-cp.eu/GCP/2019',
    type: [],
    data: []
  }
  // number of columns in CSV file, for discarding empty columns
  let nCols = 0;

  // see if input-file exists, abort if not
  if (fn === undefined || fn === true || fn === '' || !fs.existsSync(fn)) {
    console.log('File not found:', fn);
    process.exit();
  }

  // Ready to process the CSV file
  fs.createReadStream(fn)
    .pipe(parse({ delimiter: ',' }))
    .on('data', csvRow => {
      if (csvRow[1].includes('Source of')) {
        // add the source information
        d.source += ' ' + csvRow[1];
      } else if (csvRow[1].includes('Cite as: ')) {
        // additional source information
        d.source += csvRow[1].replace('Cite as: ', '') + ' / ';
      } else if (csvRow[0] === 'Year') {
        // list of fuel types, with 'Year' in column 0
        csvRow.shift();
        // find first empty column, discard from there
        nCols = csvRow.indexOf('');
        if (nCols > -1) {
          csvRow.splice(nCols);
        }
        d.type = csvRow;
      } else {
        // process the yearly data, 'year' is first element in the row
        let y = csvRow.shift();
        if (nCols > -1) {
          csvRow.splice(nCols);
        }
        // skip any empty rows
        if (y.length && (y > 1700) && (y < 2100)) {
          // multiply all values by 3.664 to convert from C to CO2
          let v = csvRow.map(x => Math.floor(x * 366.4) / 100);
          d.data.push({
            year: y,
            data: v
          });
        }
      }
    })
    .on('end', () => {
      let s = JSON.stringify(d);
      // Store to Redis if key is specified
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
