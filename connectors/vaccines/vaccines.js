// vaccines.js
//
// Turn JHU CSV-files into JSON data and store to Redis
//
// H. Dahle, 2021

var fs = require('fs');
var parse = require('csv-parse');
var redis = require('redis');
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';
const regionNames = ['Oceania', 'Asia', 'Europe', 'Northern America', 'Latin America', 'Africa'];


// Country population data from Wikipedia
const worldPop = [
  { c: "World", p: 7800000000, r: "World"},
  { c: "China", p: 1433783686, r: "Asia" },
  { c: "India", p: 1366417754, r: "Asia" },
  { c: "US", p: 329064917, r: "Northern America" },
  { c: "Indonesia", p: 270625568, r: "Asia" },
  { c: "Pakistan", p: 216565318, r: "Asia" },
  { c: "Brazil", p: 211049527, r: "Latin America" },
  { c: "Nigeria", p: 200963599, r: "Africa" },
  { c: "Bangladesh", p: 163046161, r: "Asia" },
  { c: "Russia", p: 145872256, r: "Europe" },
  { c: "Mexico", p: 127575529, r: "Northern America" },
  { c: "Japan", p: 126860301, r: "Asia" },
  { c: "Ethiopia", p: 112078730, r: "Africa" },
  { c: "Philippines", p: 108116615, r: "Asia" },
  { c: "Egypt", p: 100388073, r: "Africa" },
  { c: "Vietnam", p: 96462106, r: "Asia" },
  //{ c: "DR Congo", p: 86790567, r: "Africa" },
  { c: "Congo (Kinshasa)", p: 86790567, r: "Africa" },
  { c: "Germany", p: 83517045, r: "Europe" },
  { c: "Turkey", p: 83429615, r: "Asia" },
  { c: "Iran", p: 82913906, r: "Asia" },
  { c: "Thailand", p: 69037513, r: "Asia" },
  { c: "UK", p: 67530172, r: "Europe" },
  //{ c: "United Kingdom", p: 67530172, r: "Europe" },
  { c: "France", p: 65129728, r: "Europe" },
  { c: "Italy", p: 60550075, r: "Europe" },
  { c: "South Africa", p: 58558270, r: "Africa" },
  { c: "Tanzania", p: 58005463, r: "Africa" },
  { c: "Myanmar", p: 54045420, r: "Asia" },
  { c: "Burma", p: 54045420, r: "Asia" },
  { c: "Kenya", p: 52573973, r: "Africa" },
  { c: "South Korea", p: 51225308, r: "Asia" },
  //{ c: "Korea, South", p: 51225308, r: "Asia" },
  { c: "Colombia", p: 50339443, r: "Latin America" },
  { c: "Spain", p: 46736776, r: "Europe" },
  { c: "Argentina", p: 44780677, r: "Latin America" },
  { c: "Uganda", p: 44269594, r: "Africa" },
  { c: "Ukraine", p: 43993638, r: "Europe" },
  { c: "Algeria", p: 43053054, r: "Africa" },
  { c: "Sudan", p: 42813238, r: "Africa" },
  { c: "Iraq", p: 39309783, r: "Asia" },
  { c: "Afghanistan", p: 38041754, r: "Asia" },
  { c: "Poland", p: 37887768, r: "Europe" },
  { c: "Canada", p: 37411047, r: "Northern America" },
  { c: "Morocco", p: 36471769, r: "Africa" },
  { c: "Saudi Arabia", p: 34268528, r: "Asia" },
  { c: "Uzbekistan", p: 32981716, r: "Asia" },
  { c: "Peru", p: 32510453, r: "Latin America" },
  { c: "Malaysia", p: 31949777, r: "Asia" },
  { c: "Angola", p: 31825295, r: "Africa" },
  { c: "Mozambique", p: 30366036, r: "Africa" },
  { c: "Yemen", p: 29161922, r: "Asia" },
  { c: "Ghana", p: 28833629, r: "Africa" },
  { c: "Nepal", p: 28608710, r: "Asia" },
  { c: "Venezuela", p: 28515829, r: "Latin America" },
  { c: "Madagascar", p: 26969307, r: "Africa" },
  { c: "North Korea", p: 25666161, r: "Asia" },
  //{ c: "Ivory Coast", p: 25716544, r: "Africa" },
  { c: "Cote d'Ivoire", p: 25716544, r: "Africa" },
  { c: "Cameroon", p: 25876380, r: "Africa" },
  { c: "Australia", p: 25203198, r: "Oceania" },
  { c: "Taiwan", p: 23773876, r: "Asia" },
  { c: "Taiwan*", p: 23773876, r: "Asia" },
  { c: "Niger", p: 23310715, r: "Africa" },
  { c: "Sri Lanka", p: 21323733, r: "Asia" },
  { c: "Burkina Faso", p: 20321378, r: "Africa" },
  { c: "Mali", p: 19658031, r: "Africa" },
  { c: "Romania", p: 19364557, r: "Europe" },
  { c: "Malawi", p: 18628747, r: "Africa" },
  { c: "Chile", p: 18952038, r: "Latin America" },
  { c: "Kazakhstan", p: 18551427, r: "Asia" },
  { c: "Zambia", p: 17861030, r: "Africa" },
  { c: "Guatemala", p: 17581472, r: "Latin America" },
  { c: "Ecuador", p: 17373662, r: "Latin America" },
  { c: "Netherlands", p: 17097130, r: "Europe" },
  { c: "Syria", p: 17070135, r: "Asia" },
  { c: "Cambodia", p: 16486542, r: "Asia" },
  { c: "Senegal", p: 16296364, r: "Africa" },
  { c: "Chad", p: 15946876, r: "Africa" },
  { c: "Somalia", p: 15442905, r: "Africa" },
  { c: "Zimbabwe", p: 14645468, r: "Africa" },
  { c: "Guinea", p: 12771246, r: "Africa" },
  { c: "Rwanda", p: 12626950, r: "Africa" },
  { c: "Benin", p: 11801151, r: "Africa" },
  { c: "Tunisia", p: 11694719, r: "Africa" },
  { c: "Belgium", p: 11539328, r: "Europe" },
  { c: "Bolivia", p: 11513100, r: "Latin America" },
  { c: "Cuba", p: 11333483, r: "Latin America" },
  { c: "Haiti", p: 11263770, r: "Latin America" },
  { c: "South Sudan", p: 11062113, r: "Africa" },
  { c: "Burundi", p: 10864245, r: "Africa" },
  { c: "Dominican Republic", p: 10738958, r: "Latin America" },
  { c: "Czech Republic", p: 10689209, r: "Europe" },
  // { c: "Czechia", p: 10689209, r: "Europe" },
  { c: "Greece", p: 10473455, r: "Europe" },
  { c: "Portugal", p: 10226187, r: "Europe" },
  { c: "Jordan", p: 10101694, r: "Asia" },
  { c: "Azerbaijan", p: 10047718, r: "Asia" },
  { c: "Sweden", p: 10036379, r: "Europe" },
  { c: "United Arab Emirates", p: 9770529, r: "Asia" },
  { c: "Honduras", p: 9746117, r: "Latin America" },
  { c: "Hungary", p: 9684679, r: "Europe" },
  { c: "Belarus", p: 9452411, r: "Europe" },
  { c: "Tajikistan", p: 9321018, r: "Asia" },
  { c: "Austria", p: 8955102, r: "Europe" },
  { c: "Papua New Guinea", p: 8776109, r: "Oceania" },
  { c: "Serbia", p: 8772235, r: "Europe" },
  { c: "Switzerland", p: 8591365, r: "Europe" },
  { c: "Israel", p: 8519377, r: "Asia" },
  { c: "Togo", p: 8082366, r: "Africa" },
  { c: "Sierra Leone", p: 7813215, r: "Africa" },
  { c: "Hong Kong", p: 7436154, r: "Asia" },
  { c: "Laos", p: 7169455, r: "Asia" },
  { c: "Paraguay", p: 7044636, r: "Latin America" },
  { c: "Bulgaria", p: 7000119, r: "Europe" },
  { c: "Lebanon", p: 6855713, r: "Asia" },
  { c: "Libya", p: 6777452, r: "Africa" },
  { c: "Nicaragua", p: 6545502, r: "Latin America" },
  { c: "El Salvador", p: 6453553, r: "Latin America" },
  { c: "Kyrgyzstan", p: 6415850, r: "Asia" },
  { c: "Turkmenistan", p: 5942089, r: "Asia" },
  { c: "Singapore", p: 5804337, r: "Asia" },
  { c: "Denmark", p: 5771876, r: "Europe" },
  { c: "Finland", p: 5532156, r: "Europe" },
  { c: "Slovakia", p: 5457013, r: "Europe" },
  { c: "Congo (Brazzaville)", p: 5380508, r: "Africa" },
  { c: "Norway", p: 5378857, r: "Europe" },
  { c: "Costa Rica", p: 5047561, r: "Latin America" },
  { c: "Palestine", p: 4981420, r: "Asia" },
  { c: "Oman", p: 4974986, r: "Asia" },
  { c: "Liberia", p: 4937374, r: "Africa" },
  { c: "Ireland", p: 4882495, r: "Europe" },
  { c: "New Zealand", p: 4783063, r: "Oceania" },
  { c: "Central African Republic", p: 4745185, r: "Africa" },
  { c: "Mauritania", p: 4525696, r: "Africa" },
  { c: "Panama", p: 4246439, r: "Latin America" },
  { c: "Kuwait", p: 4207083, r: "Asia" },
  { c: "West Bank and Gaza", p: 4170000, r: "Asia" },
  { c: "Croatia", p: 4130304, r: "Europe" },
  { c: "Moldova", p: 4043263, r: "Europe" },
  { c: "Georgia", p: 3996765, r: "Asia" },
  { c: "Eritrea", p: 3497117, r: "Africa" },
  { c: "Uruguay", p: 3461734, r: "Latin America" },
  { c: "Bosnia and Herzegovina", p: 3301000, r: "Europe" },
  { c: "Mongolia", p: 3225167, r: "Asia" },
  { c: "Armenia", p: 2957731, r: "Asia" },
  { c: "Jamaica", p: 2948279, r: "Latin America" },
  { c: "Puerto Rico", p: 2933408, r: "Latin America" },
  { c: "Albania", p: 2880917, r: "Europe" },
  { c: "Qatar", p: 2832067, r: "Asia" },
  { c: "Lithuania", p: 2759627, r: "Europe" },
  { c: "Namibia", p: 2494530, r: "Africa" },
  { c: "Gambia", p: 2347706, r: "Africa" },
  { c: "Botswana", p: 2303697, r: "Africa" },
  { c: "Gabon", p: 2172579, r: "Africa" },
  { c: "Lesotho", p: 2125268, r: "Africa" },
  { c: "North Macedonia", p: 2083459, r: "Europe" },
  { c: "Slovenia", p: 2078654, r: "Europe" },
  { c: "Guinea-Bissau", p: 1920922, r: "Africa" },
  { c: "Latvia", p: 1906743, r: "Europe" },
  { c: "Kosovo", p: 1793000, r: "Europe" },
  { c: "Bahrain", p: 1641172, r: "Asia" },
  { c: "Trinidad and Tobago", p: 1394973, r: "Latin America" },
  { c: "Equatorial Guinea", p: 1355986, r: "Africa" },
  { c: "Estonia", p: 1325648, r: "Europe" },
  { c: "East Timor", p: 1293119, r: "Asia" },
  { c: "Timor-Leste", p: 1293119, r: "Asia" },
  { c: "Mauritius", p: 1198575, r: "Africa" },
  { c: "Cyprus", p: 1179551, r: "Europe" },
  { c: "Eswatini", p: 1148130, r: "Africa" },
  { c: "Djibouti", p: 973560, r: "Africa" },
  { c: "Fiji", p: 889953, r: "Oceania" },
  { c: "Réunion", p: 888927, r: "Africa" },
  { c: "Reunion", p: 888927, r: "Africa" },
  { c: "Comoros", p: 850886, r: "Africa" },
  { c: "Guyana", p: 782766, r: "Latin America" },
  { c: "Bhutan", p: 763092, r: "Asia" },
  { c: "Solomon Islands", p: 669823, r: "Oceania" },
  { c: "Macau", p: 640445, r: "Asia" },
  { c: "Montenegro", p: 627987, r: "Europe" },
  { c: "Luxembourg", p: 615729, r: "Europe" },
  { c: "Western Sahara", p: 582463, r: "Africa" },
  { c: "Suriname", p: 581372, r: "Latin America" },
  { c: "Cape Verde", p: 549935, r: "Africa" },
  { c: "Cabo Verde", p: 549935, r: "Africa" },
  { c: "Maldives", p: 530953, r: "Asia" },
  { c: "Guadeloupe", p: 447905, r: "Latin America" },
  { c: "Malta", p: 440372, r: "Europe" },
  { c: "Brunei", p: 433285, r: "Asia" },
  { c: "Belize", p: 390353, r: "Latin America" },
  { c: "Bahamas", p: 389482, r: "Latin America" },
  { c: "Martinique", p: 375554, r: "Latin America" },
  { c: "Iceland", p: 339031, r: "Europe" },
  { c: "Vanuatu", p: 299882, r: "Oceania" },
  { c: "Barbados", p: 287025, r: "Latin America" },
  { c: "New Caledonia", p: 282750, r: "Oceania" },
  { c: "French Guiana", p: 282731, r: "Latin America" },
  { c: "French Polynesia", p: 279287, r: "Oceania" },
  { c: "Mayotte", p: 266150, r: "Africa" },
  { c: "São Tomé and Príncipe", p: 215056, r: "Africa" },
  { c: "Sao Tome and Principe", p: 215056, r: "Africa" },
  { c: "Samoa", p: 197097, r: "Oceania" },
  { c: "Saint Lucia", p: 182790, r: "Latin America" },
  { c: "Guernsey and Jersey", p: 172259, r: "Europe" },
  { c: "Guam", p: 167294, r: "Oceania" },
  { c: "Curacao", p: 163424, r: "Latin America" },
  { c: "Kiribati", p: 117606, r: "Oceania" },
  { c: "F.S. Micronesia", p: 113815, r: "Oceania" },
  { c: "Micronesia", p: 113815, r: "Oceania" },
  { c: "Grenada", p: 112003, r: "Latin America" },
  { c: "Tonga", p: 110940, r: "Oceania" },
  { c: "Saint Vincent and the Grenadines", p: 110589, r: "Latin America" },
  { c: "Aruba", p: 106314, r: "Latin America" },
  { c: "U.S. Virgin Islands", p: 104578 },
  { c: "Seychelles", p: 97739, r: "Africa" },
  { c: "Antigua and Barbuda", p: 97118, r: "Latin America" },
  { c: "Isle of Man", p: 84584, r: "Europe" },
  { c: "Andorra", p: 77142, r: "Europe" },
  { c: "Dominica", p: 71808, r: "Latin America" },
  { c: "Cayman Islands", p: 64948, r: "Latin America" },
  { c: "Bermuda", p: 62506, r: "Northern America" },
  { c: "Marshall Islands", p: 58791, r: "Oceania" },
  { c: "Greenland", p: 56672, r: "Northern America" },
  { c: "Northern Mariana Islands", p: 56188, r: "Oceania" },
  { c: "American Samoa", p: 55312, r: "Oceania" },
  { c: "Saint Kitts and Nevis", p: 52823, r: "Latin America" },
  { c: "Faroe Islands", p: 48678, r: "Europe" },
  { c: "Sint Maarten", p: 42388, r: "Latin America" },
  { c: "St. Martin", p: 42388, r: "Latin America" },
  { c: "Monaco", p: 38964, r: "Europe" },
  { c: "Turks and Caicos Islands", p: 38191, r: "Latin America" },
  { c: "Liechtenstein", p: 38019, r: "Europe" },
  { c: "San Marino", p: 33860, r: "Europe" },
  { c: "Gibraltar", p: 33701, r: "Europe" },
  { c: "British Virgin Islands", p: 30030, r: "Latin America" },
  { c: "Caribbean Netherlands", p: 25979, r: "Latin America" },
  { c: "Palau", p: 18008, r: "Oceania" },
  { c: "Cook Islands", p: 17548, r: "Oceania" },
  { c: "Anguilla", p: 14869, r: "Latin America" },
  { c: "Tuvalu", p: 11646, r: "Oceania" },
  { c: "Wallis and Futuna", p: 11432, r: "Oceania" },
  { c: "Nauru", p: 10756, r: "Oceania" },
  { c: "Saint Helena, Ascension and Tristan da Cunha", p: 6059, r: "Africa" },
  { c: "Saint Barthelemy", p: 9800, r: "Latin America" },
  { c: "Saint Pierre and Miquelon", p: 5822, r: "Northern America" },
  { c: "Montserrat", p: 4989, r: "Latin America" },
  { c: "Diamond Princess", p: 3711, r: "Ship" },
  { c: "Others", p: 3711, r: "Ship" },
  { c: "Falkland Islands", p: 3377, r: "Latin America" },
  { c: "Niue", p: 1615, r: "Oceania" },
  { c: "MS Zaandam", p: 2047, r: "Ship" },
  { c: "Tokela", p: 1340, r: "Oceania" },
  { c: "Tokelau", p: 1340, r: "Oceania" },
  { c: "Vatican City", p: 799, r: "Europe" },
  { c: "Holy See", p: 799, r: "Europe" }
];


// Parse commandline

  const fn = argv.file; // filename from cmd line
  const redisKey = argv.key; // redis-key from cmd line
  const summaryOnly = argv.summaryOnly;
  const verbose = argv.verbose;
  let cList = (argv.countries === undefined) ? ['All'] : argv.countries.split(','); // list of countries
  let countriesOK = cList.every(x =>
    //['World', 'All', 'top20', 'regions'].includes(x) || worldPop.findIndex(c => c.c === x) > -1 || worldPop.findIndex(c => c.r === x) > -1
    ['All'].includes(x) || worldPop.findIndex(c => c.c === x) > -1 || worldPop.findIndex(c => c.r === x) > -1
    );
  if (!countriesOK || fn === undefined || fn === true || !fs.existsSync(fn) || redisKey === undefined || redisKey === true || redisKey === '') {
    console.log('Usage:\n\tnode vaccines.js --file <csvfile> [--countries <country,country,..,country>] --key <rediskey>');
    console.log('\n')
    //console.log('\t--countries=top20\n\t\tgenerate list of top 20 countries w.r.t. deaths per million')
    //console.log('\t--countries=regions\n\t\tgenerate time-series data for Europe, Asia, Northern America, Latin America, Africa, Oceania')
    console.log('\t--countries="Norway,France,Japan,South Korea"\n\t\tgenerate time-series data for the specified countries only')
    console.log('\t--countries=All\n\t\tgenerate time-series data for the specified countries only')
    process.exit();
  }
  if (cList[0] === 'All') {
    cList = worldPop.map(x => x.c);
  }

  if (verbose) {
    console.log(moment().format(momFmt) + ' Input file:', fn)
    console.log(moment().format(momFmt) + ' Countries:', cList)
    console.log(moment().format(momFmt) + ' Redis key:', redisKey)
  }
  if (cList[0] === 'regions') {
    cList = regionNames;
  }

  // Create the Redisclient
  // When the redis client is ready, start processing input file
  var redClient = redis.createClient();
  redClient.on('connect', function () {
    console.log(moment().format(momFmt) + ' Redis client connected');
  });
  redClient.on('ready', function () {
    console.log(moment().format(momFmt) + ' Redis client ready');
    processFile(fn, redisKey, redClient, cList, summaryOnly);
  });
  redClient.on('warning', function () {
    console.log(moment().format(momFmt) + ' Redis warning');
  });
  redClient.on('error', function (err) {
    console.log(moment().format(momFmt) + ' Redis error:' + err);
  });
  redClient.on('end', function () {
    console.log(moment().format(momFmt) + ' Redis closing');
    process.exit();
  });

//
// Save to Redis, then quit Redis. On 'end' Redis will terminate this node.js process
//
function redisSave(key, value, redClient) {
  console.log(moment().format(momFmt) + ' Store:' + value.length + ' Key=' + key + ' Val=' + value.substring(0, 60));
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
function processFile(fn, redisKey, redClient, cList, summaryOnly) {
  let result = [];
  let firstLineFound = false;
  // result = [{
  //      country,
  //      region,
  //      data {
  //        datasets[{
  //          label = partial | full,
  //          data[{date,value}]
  //        }
  //      }]
  //    }]

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
      if (csv[7].length>0) {
        return;
      }
      // Now process each line of country-data
      let cName = countryName(csv[0]);
      let country = worldPop.find(x => x.c === cName);
      if (country === undefined) {
        console.log('Warning: Undefined country, skipping', cName);
        return;
      }

      // Only process countries specified in cList
      if (!cList.find(x => x === country.c)) {
        return;
      }

      // Does country already exist in result? If not, push new country     
      let a = result.find(x => x.country == country.c);
      if (a === undefined) {
        if (verbose) console.log('Processing', country.c);
        a = {
          country: country.c,
          region: country.r,
          data:{
            datasets: [{
              label: "Partial",
              data: []
            },{
              label: "Full",
              data: []
            }]
          }
        }
        result.push(a)
      }
      a.data.datasets[0].data.push({
        x: csv[1], y: Math.trunc(1000 *csv[3] / country.p)/10, n: parseInt(csv[3],10)
      })
      a.data.datasets[1].data.push({  
        x: csv[1], y: Math.trunc(1000 *csv[4] / country.p)/10, n: parseInt(csv[4],10)
      })
    })
    .on('end', () => {
      console.log('Number of countries:', result.length)
      if (!firstLineFound) {
        console.log('Error: First line in file not found');
        return;
      }
      // Store key/value pair to Redis
      let val = {
        source: 'Johns Hopkins University, https://github.com/govex/COVID-19',
        link: 'https://github.com/govex/COVID-19/blob/master/data_tables/vaccine_data/global_data/time_series_covid19_vaccine_global.csv',
        info: 'Data is specified thus: { x: date, y: percentage-of-population-vaccinated, n: number-of-people-vaccinated}',
        accessed: moment().format('YYYY-MM-DD hh:mm'),
        numberOfCountries: result.length,
        data: result
      };
      redisSave(redisKey, JSON.stringify(val), redClient);
    })
    .on('close', () => {
      console.log('Readstream closed');
    })
    .on('error', err => {
      console.log('Readstream error:', err)
    })
}


//
// The raw data contains some country names that should be changed
// Returns "standard" name if a match is found, returns input if not found
//
function countryName(country) {
  let countryNameMap = [
    { n: "Korea, South", standard: "South Korea" },
    { n: "Burma", standard: "Myanmar" },
    { n: "United Kingdom", standard: "UK" },
    { n: "Mainland China", standard: "China" },
    { n: "Taiwan*", standard: "Taiwan" },
    { n: "Holy See", standard: "Italy" },
    { n: "Vatican City", standard: "Italy" },
    { n: "San Marino", standard: "Italy" },
    { n: "Monaco", standard: "France" },
    { n: "Czechia", standard: "Czech Republic" },
    { n: "USA", standard: "US" }
  ];
  let x = countryNameMap.find(x => x.n === country);
  return (x === undefined) ? country : x.standard;
}


