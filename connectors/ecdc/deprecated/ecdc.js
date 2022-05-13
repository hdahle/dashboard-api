// ecdc.js
//
// Convert ECDC XLSX files to JSON and store to Redis
//
// H.Dahle, 2020

let XLSX = require('xlsx');
let moment = require('moment');
let argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';
// Command-line arguments
let verbose = argv.verbose;
let fileName = argv.file;
let redisKey = argv.key;

if (fileName === undefined || fileName === true || redisKey === undefined || redisKey === true || redisKey === '') {
  console.log('Usage: node script --file <filename> --key <rediskey> [--verbose]');
  console.log('  filename: name of XLSX file downloaded from ECDC');
  console.log('  rediskey: a string such as \'ecdc\' to which this script adds either \'-weekly\' or \'-daily\'');
  return;
}

console.log(moment().format(momFmt), process.argv[1]);

// Open workbook
let workbook;
try {
  workbook = XLSX.readFile(fileName);
} catch (err) {
  console.log('Unable to open file', fileName)
  return;
}

// Start Redis-client
var redClient = require('redis').createClient();
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
  console.log(moment().format(momFmt) + ' Redis end');
});

// Parse workbook
if (verbose) {
  console.log(moment().format(momFmt), 'Modified date:', workbook.Props.ModifiedDate);
  console.log(moment().format(momFmt), 'Number of sheets:', workbook.Workbook.Sheets.length);
}

// Find number of worksheets, should be 1
let numSheets = workbook.Props.Worksheets
if (numSheets != 1) {
  console.log(moment().format(momFmt), 'Unexpected number of sheets:', numSheets);
  return;
}

// Find the name of the worksheet, usually 'Sheet1'
let sheetNames = workbook.Props.SheetNames
if (!sheetNames) {
  console.log(moment().format(momFmt), 'Unable to find SheetNames in Worksheet')
  return;
}
if (verbose)
  console.log(moment().format(momFmt), 'Sheetnames:', sheetNames);

if (sheetNames.length !== 1) {
  console.log(moment().format(momFmt), 'Unexpected number of sheetNames, should be 1, found:', sheetNames.length);
  //return;
}

// Grab the sheetname and find the sheet
let sheetName = sheetNames[0];
if (!workbook.Sheets[sheetName]) {
  console.log(moment().format(momFmt), 'Unable to find sheet', sheetName);
  return;
}
let sheet = workbook.Sheets[sheetName];

// Find the range of cells, usually A1-F10XXXX
let range = sheet['!ref'];
let cells = range.match(/[A-Z][0-9]+/g);
if (!cells) {
  console.log(moment().format(momFmt), 'Unable to find cell range in Worksheet');
  return;
}

// Parse the range
let cellFirstRow = cells[0].match(/[0-9]+/);
let cellLastRow = cells[1].match(/[0-9]+/);
let cellFirstCol = cells[0].match(/[A-Z]+/);
let cellLastCol = cells[1].match(/[A-Z]+/);
if (!cellFirstRow || !cellFirstRow || !cellLastRow || !cellLastCol) {
  console.log(moment().format(momFmt), 'Unable to parse cell range')
  return;
}

// Columns should be single-letters only
if (cellFirstCol[0].length !== 1 || cellLastCol[0].length !== 1) {
  console.log(moment().format(momFmt), 'Unexpected column range');
  return;
}

// Convert column LETTER to number, A = 65
let colMin = cellFirstCol[0].toUpperCase().charCodeAt(0)
let colMax = cellLastCol[0].toUpperCase().charCodeAt(0)
let rowMin = parseInt(cellFirstRow[0]);
let rowMax = parseInt(cellLastRow[0]);

// This is the default worksheet column usage
let country = 'A';
let region = 'B';
let date = 'D';
let value = 'E';
let weekly = true;

// Figure out the actual column usage
for (let ch = colMin; ch <= colMax; ch++) {
  let cellIndex = String.fromCharCode(ch) + rowMin.toString();
  switch (sheet[cellIndex].v) {
    case 'country': country = cellIndex.charAt(0); break;
    case 'region_name': region = cellIndex.charAt(0); break;
    case 'year_week': date = cellIndex.charAt(0); break;
    case 'date': date = cellIndex.charAt(0); weekly = false; break;
    case 'rate_14_day_per_100k': value = cellIndex.charAt(0); break;
  }
}

if (verbose) {
  console.log(moment().format(momFmt), 'Daily or weekly? ', (weekly) ? 'weekly' : 'daily')
}
let jsonDateFormat = (weekly) ? 'YYYYWW' : 'YYYY-MM-DD';

// Now process the entire file row by row
let results = [];
let undefs = 0;
for (let i = rowMin + 1; i <= rowMax; i++) {
  // Skip rows without value in E
  if (sheet[value + i] === undefined) {
    undefs++;
    continue;
  }
  // Access the data for this row
  let countryName = sheet[country + i].v;
  let regionName = sheet[region + i].v;
  let dateStamp = moment(sheet[date + i].v).format(jsonDateFormat);
  let dataValue = Math.round(sheet[value + i].v);
  // We need to handle some special cases, such as \n in region names
  if (regionName.toUpperCase().includes('BRUXELLES')) regionName = 'Brussels';
  if (regionName.toUpperCase().includes('BOLZANO')) regionName = 'Bolzano';
  if (regionName.toUpperCase().includes('VALLE D\'AOSTA')) regionName = 'Valle d\'aosta';
  // If country does not exist, push country with region and data
  let idx = results.findIndex(x => x.country === countryName)
  if (idx === -1) {
    results.push({
      country: countryName,
      region: [{
        name: regionName,
        data: [{
          t: dateStamp,
          v: dataValue
        }]
      }]
    })
    continue;
  }
  // Country exists, but does region exist?
  let x = results[idx].region.findIndex(r => r.name === regionName);
  if (x === -1) {
    results[idx].region.push({
      name: regionName,
      data: [{
        t: dateStamp,
        v: dataValue
      }]
    })
    continue;
  }
  // Country and region both exist, push data only
  if (moment(dateStamp, jsonDateFormat).isBefore(moment().add(-6, 'weeks'))) continue;
  results[idx].region[x].data.push({
    t: dateStamp,
    v: dataValue
  });
}

// Some useful debug info
if (verbose) {
  let n = results.length
  let m = 0;
  results.forEach(r => {
    m += r.region.length
  });
  console.log(moment().format(momFmt), 'Countries:', n, 'Regions:', m)
  console.log(moment().format(momFmt), 'Rows processed:', rowMax - rowMin + 1, 'Undefs:', undefs)
}

// Create JSON for storing into Redis
let redisVal = JSON.stringify({
  source: 'European Centre for Disease Prevention and Control, https://www.ecdc.europa.eu/en',
  link: 'https://www.ecdc.europa.eu/en/publications-data/weekly-subnational-14-day-notification-rate-covid-19',
  copyright: 'https://www.ecdc.europa.eu/en/copyright',
  info: 'Data is adapted from XLSX files downloaded from ECDC weekly',
  accessed: workbook.Props.ModifiedDate,
  dateformat: jsonDateFormat,
  countries: results.map(x => x.country),
  data: results
});

// Store key/value pair to Redis
redClient.set(redisKey, redisVal, function (error, result) {
  if (result) {
    console.log(moment().format(momFmt), 'Redis result:', result, 'Bytes:', redisVal.length, 'Key:', redisKey);
  } else {
    console.log(moment().format(momFmt), 'Redis error: ', error);
  }
  redClient.quit();
});

// We're done