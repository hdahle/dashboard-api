// covid.js
//
// Turn JHU CSV-files into JSON data and store to Redis
//
// H. Dahle, 2020

var fs = require('fs');
var parse = require('csv-parse');
var redis = require('redis');
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';

main();

function main() {
  let fn = argv.file; // filename from cmd line
  let redisKey = argv.key; // redis-key from cmd line
  if (fn === undefined || fn === '' || fn === true || !fs.existsSync(fn) || redisKey === undefined || redisKey === true || redisKey === '') {
    console.log('Usage: node covid.js --file <csvfile> --key <rediskey>');
    return;
  }
  var redClient = redis.createClient();
  redClient.on('connect', function () {
    console.log(moment().format(momFmt) + ' Redis client connected');
  });
  redClient.on('ready', function () {
    console.log(moment().format(momFmt) + ' Redis client ready');
    processFile(fn, redisKey, redClient);
  });
  redClient.on('warning', function () {
    console.log(moment().format(momFmt) + ' Redis warning');
  });
  redClient.on('error', function (err) {
    console.log(moment().format(momFmt) + ' Redis error:' + err);
  });
}

function processFile(fn, redisKey, redClient) {
  // cmdline OK, now read file - one or more lines per country
  let countries = [];
  let csvDates = [];
  fs.createReadStream(fn)
    .pipe(parse({ delimiter: ',' }))
    .on('data', csv => {
      // This is the first line in the CSV file
      if (csv[0] === 'Province/State') {
        // CSV-line: region , country, lat, long, dates.....
        csvDates = csv.slice(4).map(x => moment(x, "M/D/YY").format("YYYY-MM-DD"));
        return;
      }
      // Now process each line of country-data
      let cName = countryName(csv[1]);
      let cPop = p(cName) / 1000000;
      let d = [];
      for (let i = 4; i < csv.length; i++) {
        d.push({
          t: csvDates[i - 4],
          y: parseInt(csv[i], 10),
          d: parseInt(i > 4 ? csv[i] - csv[i - 1] : csv[i], 10),
          ypm: 0,
          c: 0
        });
      }
      // Each country may have several entries which should be added together
      let idx = countries.findIndex(x => x.country === cName);
      if (idx === -1) {
        countries.push({
          country: cName,
          population: Math.floor(100 * cPop) / 100,
          data: d
        })
      } else {
        let d = countries[idx].data;
        for (let i = 0; i < d.length; i++) {
          d[i].y += parseInt(csv[i + 4], 10);
          d[i].d = i > 0 ? (d[i].y - d[i - 1].y) : d[i].y
        }
      }
    })
    .on('end', () => {
      // calculate smoothed increase in percent
      countries.push(calculateWorld(countries));
      // calculate smoothed rate of increase
      countries.forEach(x => x.data = smoothData(x.data));
      // calculate YPM
      countries.forEach(c => c.data.forEach((x => x.ypm = Math.trunc(10 * x.y / c.population) / 10)));

      let d = {
        source: '"2019 Novel Coronavirus COVID-19 (2019-nCoV) Data Repository by Johns Hopkins CSSE, https://systems.jhu.edu. Population figures from Wikipedia/UN"',
        license: '"README.md in the Github repo says: This GitHub repo and its contents herein, including all data, mapping, and analysis, copyright 2020 Johns Hopkins University, all rights reserved, is provided to the public strictly for educational and academic research purposes. The Website relies upon publicly available data from multiple sources, that do not always agree. The Johns Hopkins University hereby disclaims any and all representations and warranties with respect to the Website, including accuracy, fitness for use, and merchantability. Reliance on the Website for medical guidance or use of the Website in commerce is strictly prohibited"',
        link: '"https://github.com/CSSEGISandData/COVID-19"',
        info: '"Data format: [ {country: string, population:number, data:[{t:time, y:cumulative-data, d:daily-data, c:daily-change,ypm:y-per-million},...,{}]}]. Note that daily-change is based on 3-day averaged daily-data"',
        data: countries
      }
      // Store key/value pair to Redis
      let val = JSON.stringify(d);
      console.log(moment().format(momFmt) + ' Store:' + val.length + ' Key=' + redisKey + ' Val=' + val.substring(0, 100));
      redClient.set(redisKey, val, function (error, result) {
        if (result) {
          console.log(moment().format(momFmt) + ' Result:' + result);
        } else {
          console.log(moment().format(momFmt) + ' Error: ' + error);
        }
        setTimeout(() => { process.exit(); }, 1000);
      });
    })
    .on('close', () => {
      console.log('Readstream closed');
    })
    .on('error', err => {
      console.log('Readstream error:', err)
    })
}

//
// Calculate the values for World where .y and .d are sum of all countries
//
function calculateWorld(countries) {
  if (countries === undefined || countries === null || !Array.isArray(countries) || countries.length === 0) {
    return null;
  }
  if (countries[0].data === undefined || !Array.isArray(countries[0].data)) {
    return null;
  }
  let population = 0;
  // initialize d array with empties
  let d = [];
  for (let i = 0; i < countries[0].data.length; i++) {
    d.push({ y: 0, d: 0 })
  }
  // now add up all the data arrays
  countries.forEach(c => {
    population += c.population;
    for (let i = 0; i < c.data.length; i++) {
      d[i] = {
        y: d[i].y + c.data[i].y,
        d: d[i].d + c.data[i].d
      }
    }
  });
  return { country: 'World', population: population, data: d };
}

// smoothData
// Input: 
// d = {
//   t: 
//   y: cumulative data
//   d: daily difference
//   c: daily change in percent
// }
// We create a smoothed series of daily values,
// and then a series of daily change based on smoothed daily values
// We do not change the daily values d.d, we only compute d.c
// Output: d = {
//  t: y: d: c: 
// }
function smoothData(d) {
  if (d === undefined || d === null || !Array.isArray(d) || d.length === 0) return null;

  let smoothY = []; // Smoothed array of cumulative cases, using d[].y
  let smoothD = []; // Smoothed array of daily change, smooth[i].y - smooth[i-1].y

  // First calculate smoothY[]
  for (let i = 0; i < d.length; i++) {
    if (d[i].y === undefined) return null;
    let y = 0; // cumulative 
    if (i === 0) {
      y = d[i].y;
    } else if (i === d.length - 1) {
      y = d[i].y;
    } else {
      y = (d[i - 1].y + d[i].y + d[i + 1].y) / 3;
    }
    smoothY[i] = y === 0 ? 1 : y;
  }

  // Then calculate smoothD[]
  for (let i = 0; i < d.length; i++) {
    if (i === 0) {
      smoothD[i] = 0;
    } else if (i === d.length - 1) {
      smoothD[i] = d[i].y - d[i - 1].y;
    } else {
      smoothD[i] = smoothY[i] - smoothY[i - 1];
    }
  }

  // Finally calculate smoothed d[].c rate of change
  for (let i = 0; i < d.length; i++) {
    if (i === 0) {
      d[i].c = 0;
    } else {
      d[i].c = Math.floor(1000 * smoothD[i] / smoothY[i - 1]) / 10;
    }
  }

  return d;
}

// The raw data contains some country names that should be changed
function countryName(country) {
  let countryNameMap = [
    { n: "Korea, South", standard: "South Korea" },
    { n: "Burma", standard: "Myanmar" },
    { n: "United Kingdom", standard: "UK" },
    { n: "Mainland China", standard: "China" },
    { n: "Taiwan*", standard: "Taiwan" },
    { n: "Holy See", standard: "Vatican City" }
  ];
  let x = countryNameMap.find(x => x.n === country);
  return (x === undefined) ? country : x.standard;
}

// Population data from Wikipedia/UN
function p(country) {
  let population = [
    { c: "China", p: 1433783686 },
    { c: "India", p: 1366417754 },
    { c: "US", p: 329064917 },
    { c: "Indonesia", p: 270625568 },
    { c: "Pakistan", p: 216565318 },
    { c: "Brazil", p: 211049527 },
    { c: "Nigeria", p: 200963599 },
    { c: "Bangladesh", p: 163046161 },
    { c: "Russia", p: 145872256 },
    { c: "Mexico", p: 127575529 },
    { c: "Japan", p: 126860301 },
    { c: "Ethiopia", p: 112078730 },
    { c: "Philippines", p: 108116615 },
    { c: "Egypt", p: 100388073 },
    { c: "Vietnam", p: 96462106 },
    { c: "DR Congo", p: 86790567 },
    { c: "Congo (Kinshasa)", p: 86790567 },
    { c: "Germany", p: 83517045 },
    { c: "Turkey", p: 83429615 },
    { c: "Iran", p: 82913906 },
    { c: "Thailand", p: 69037513 },
    { c: "UK", p: 67530172 },
    { c: "United Kingdom", p: 67530172 },
    { c: "France", p: 65129728 },
    { c: "Italy", p: 60550075 },
    { c: "South Africa", p: 58558270 },
    { c: "Tanzania", p: 58005463 },
    { c: "Myanmar", p: 54045420 },
    { c: "Burma", p: 54045420 },
    { c: "Kenya", p: 52573973 },
    { c: "South Korea", p: 51225308 },
    { c: "Korea, South", p: 51225308 },
    { c: "Colombia", p: 50339443 },
    { c: "Spain", p: 46736776 },
    { c: "Argentina", p: 44780677 },
    { c: "Uganda", p: 44269594 },
    { c: "Ukraine", p: 43993638 },
    { c: "Algeria", p: 43053054 },
    { c: "Sudan", p: 42813238 },
    { c: "Iraq", p: 39309783 },
    { c: "Afghanistan", p: 38041754 },
    { c: "Poland", p: 37887768 },
    { c: "Canada", p: 37411047 },
    { c: "Morocco", p: 36471769 },
    { c: "Saudi Arabia", p: 34268528 },
    { c: "Uzbekistan", p: 32981716 },
    { c: "Peru", p: 32510453 },
    { c: "Malaysia", p: 31949777 },
    { c: "Angola", p: 31825295 },
    { c: "Mozambique", p: 30366036 },
    { c: "Yemen", p: 29161922 },
    { c: "Ghana", p: 28833629 },
    { c: "Nepal", p: 28608710 },
    { c: "Venezuela", p: 28515829 },
    { c: "Madagascar", p: 26969307 },
    { c: "North Korea", p: 25666161 },
    { c: "Ivory Coast", p: 25716544 },
    { c: "Cote d'Ivoire", p: 25716544 },
    { c: "Cameroon", p: 25876380 },
    { c: "Australia", p: 25203198 },
    { c: "Taiwan", p: 23773876 },
    { c: "Taiwan*", p: 23773876 },
    { c: "Niger", p: 23310715 },
    { c: "Sri Lanka", p: 21323733 },
    { c: "Burkina Faso", p: 20321378 },
    { c: "Mali", p: 19658031 },
    { c: "Romania", p: 19364557 },
    { c: "Malawi", p: 18628747 },
    { c: "Chile", p: 18952038 },
    { c: "Kazakhstan", p: 18551427 },
    { c: "Zambia", p: 17861030 },
    { c: "Guatemala", p: 17581472 },
    { c: "Ecuador", p: 17373662 },
    { c: "Netherlands", p: 17097130 },
    { c: "Syria", p: 17070135 },
    { c: "Cambodia", p: 16486542 },
    { c: "Senegal", p: 16296364 },
    { c: "Chad", p: 15946876 },
    { c: "Somalia", p: 15442905 },
    { c: "Zimbabwe", p: 14645468 },
    { c: "Guinea", p: 12771246 },
    { c: "Rwanda", p: 12626950 },
    { c: "Benin", p: 11801151 },
    { c: "Tunisia", p: 11694719 },
    { c: "Belgium", p: 11539328 },
    { c: "Bolivia", p: 11513100 },
    { c: "Cuba", p: 11333483 },
    { c: "Haiti", p: 11263770 },
    { c: "South Sudan", p: 11062113 },
    { c: "Burundi", p: 10864245 },
    { c: "Dominican Republic", p: 10738958 },
    { c: "Czech Republic", p: 10689209 },
    { c: "Czechia", p: 10689209 },
    { c: "Greece", p: 10473455 },
    { c: "Portugal", p: 10226187 },
    { c: "Jordan", p: 10101694 },
    { c: "Azerbaijan", p: 10047718 },
    { c: "Sweden", p: 10036379 },
    { c: "United Arab Emirates", p: 9770529 },
    { c: "Honduras", p: 9746117 },
    { c: "Hungary", p: 9684679 },
    { c: "Belarus", p: 9452411 },
    { c: "Tajikistan", p: 9321018 },
    { c: "Austria", p: 8955102 },
    { c: "Papua New Guinea", p: 8776109 },
    { c: "Serbia", p: 8772235 },
    { c: "Switzerland", p: 8591365 },
    { c: "Israel", p: 8519377 },
    { c: "Togo", p: 8082366 },
    { c: "Sierra Leone", p: 7813215 },
    { c: "Hong Kong", p: 7436154 },
    { c: "Laos", p: 7169455 },
    { c: "Paraguay", p: 7044636 },
    { c: "Bulgaria", p: 7000119 },
    { c: "Lebanon", p: 6855713 },
    { c: "Libya", p: 6777452 },
    { c: "Nicaragua", p: 6545502 },
    { c: "El Salvador", p: 6453553 },
    { c: "Kyrgyzstan", p: 6415850 },
    { c: "Turkmenistan", p: 5942089 },
    { c: "Singapore", p: 5804337 },
    { c: "Denmark", p: 5771876 },
    { c: "Finland", p: 5532156 },
    { c: "Slovakia", p: 5457013 },
    { c: "Congo (Brazzaville)", p: 5380508 },
    { c: "Norway", p: 5378857 },
    { c: "Costa Rica", p: 5047561 },
    { c: "Palestine", p: 4981420 },
    { c: "Oman", p: 4974986 },
    { c: "Liberia", p: 4937374 },
    { c: "Ireland", p: 4882495 },
    { c: "New Zealand", p: 4783063 },
    { c: "Central African Republic", p: 4745185 },
    { c: "Mauritania", p: 4525696 },
    { c: "Panama", p: 4246439 },
    { c: "Kuwait", p: 4207083 },
    { c: "West Bank and Gaza", p: 4170000 },
    { c: "Croatia", p: 4130304 },
    { c: "Moldova", p: 4043263 },
    { c: "Georgia", p: 3996765 },
    { c: "Eritrea", p: 3497117 },
    { c: "Uruguay", p: 3461734 },
    { c: "Bosnia and Herzegovina", p: 3301000 },
    { c: "Mongolia", p: 3225167 },
    { c: "Armenia", p: 2957731 },
    { c: "Jamaica", p: 2948279 },
    { c: "Puerto Rico", p: 2933408 },
    { c: "Albania", p: 2880917 },
    { c: "Qatar", p: 2832067 },
    { c: "Lithuania", p: 2759627 },
    { c: "Namibia", p: 2494530 },
    { c: "Gambia", p: 2347706 },
    { c: "Botswana", p: 2303697 },
    { c: "Gabon", p: 2172579 },
    { c: "Lesotho", p: 2125268 },
    { c: "North Macedonia", p: 2083459 },
    { c: "Slovenia", p: 2078654 },
    { c: "Guinea-Bissau", p: 1920922 },
    { c: "Latvia", p: 1906743 },
    { c: "Kosovo", p: 1793000 },
    { c: "Bahrain", p: 1641172 },
    { c: "Trinidad and Tobago", p: 1394973 },
    { c: "Equatorial Guinea", p: 1355986 },
    { c: "Estonia", p: 1325648 },
    { c: "East Timor", p: 1293119 },
    { c: "Timor-Leste", p: 1293119 },
    { c: "Mauritius", p: 1198575 },
    { c: "Cyprus", p: 1179551 },
    { c: "Eswatini", p: 1148130 },
    { c: "Djibouti", p: 973560 },
    { c: "Fiji", p: 889953 },
    { c: "Réunion", p: 888927 },
    { c: "Comoros", p: 850886 },
    { c: "Guyana", p: 782766 },
    { c: "Bhutan", p: 763092 },
    { c: "Solomon Islands", p: 669823 },
    { c: "Macau", p: 640445 },
    { c: "Montenegro", p: 627987 },
    { c: "Luxembourg", p: 615729 },
    { c: "Western Sahara", p: 582463 },
    { c: "Suriname", p: 581372 },
    { c: "Cape Verde", p: 549935 },
    { c: "Cabo Verde", p: 549935 },
    { c: "Maldives", p: 530953 },
    { c: "Guadeloupe", p: 447905 },
    { c: "Malta", p: 440372 },
    { c: "Brunei", p: 433285 },
    { c: "Belize", p: 390353 },
    { c: "Bahamas", p: 389482 },
    { c: "Martinique", p: 375554 },
    { c: "Iceland", p: 339031 },
    { c: "Vanuatu", p: 299882 },
    { c: "Barbados", p: 287025 },
    { c: "New Caledonia", p: 282750 },
    { c: "French Guiana", p: 282731 },
    { c: "French Polynesia", p: 279287 },
    { c: "Mayotte", p: 266150 },
    { c: "São Tomé and Príncipe", p: 215056 },
    { c: "Samoa", p: 197097 },
    { c: "Saint Lucia", p: 182790 },
    { c: "Guernsey and Jersey", p: 172259 },
    { c: "Guam", p: 167294 },
    { c: "Curacao", p: 163424 },
    { c: "Kiribati", p: 117606 },
    { c: "F.S. Micronesia", p: 113815 },
    { c: "Grenada", p: 112003 },
    { c: "Tonga", p: 110940 },
    { c: "Saint Vincent and the Grenadines", p: 110589 },
    { c: "Aruba", p: 106314 },
    { c: "U.S. Virgin Islands", p: 104578 },
    { c: "Seychelles", p: 97739 },
    { c: "Antigua and Barbuda", p: 97118 },
    { c: "Isle of Man", p: 84584 },
    { c: "Andorra", p: 77142 },
    { c: "Dominica", p: 71808 },
    { c: "Cayman Islands", p: 64948 },
    { c: "Bermuda", p: 62506 },
    { c: "Marshall Islands", p: 58791 },
    { c: "Greenland", p: 56672 },
    { c: "Northern Mariana Islands", p: 56188 },
    { c: "American Samoa", p: 55312 },
    { c: "Saint Kitts and Nevis", p: 52823 },
    { c: "Faroe Islands", p: 48678 },
    { c: "Sint Maarten", p: 42388 },
    { c: "St. Martin", p: 42388 },
    { c: "Monaco", p: 38964 },
    { c: "Turks and Caicos Islands", p: 38191 },
    { c: "Liechtenstein", p: 38019 },
    { c: "San Marino", p: 33860 },
    { c: "Gibraltar", p: 33701 },
    { c: "British Virgin Islands", p: 30030 },
    { c: "Caribbean Netherlands", p: 25979 },
    { c: "Palau", p: 18008 },
    { c: "Cook Islands", p: 17548 },
    { c: "Anguilla", p: 14869 },
    { c: "Tuvalu", p: 11646 },
    { c: "Wallis and Futuna", p: 11432 },
    { c: "Nauru", p: 10756 },
    { c: "Saint Helena}, Ascension and Tristan da Cunha", p: 6059 },
    { c: "Saint Barthelemy", p: 9800 },
    { c: "Saint Pierre and Miquelon", p: 5822 },
    { c: "Montserrat", p: 4989 },
    { c: "Diamond Princess", p: 3711 },
    { c: "Others", p: 3711 },
    { c: "Falkland Islands", p: 3377 },
    { c: "Niue", p: 1615 },
    { c: "MS Zaandam", p: 2047 },
    { c: "Tokela", p: 1340 },
    { c: "Vatican City", p: 799 },
    { c: "Holy See", p: 799 }];

  let idx = population.findIndex(x => x.c === country);
  if (idx === -1) return 1;
  return population[idx].p;

}

// Exports for Mocha/Chai Testing

module.exports.p = p;
module.exports.countryName = countryName;
module.exports.smoothData = smoothData;
module.exports.calculateWorld = calculateWorld;
