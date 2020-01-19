//
// Script that fetches annual GHG Emissions data from Norway's DATA.SSB.NO
// Convert dataset into a more useful JSON object
// JSON to be stored in the api-server's Redis db
// JSON object should be easy to plot using chart.js
//

var fetch = require('node-fetch');
var redis = require('redis');
var redClient = redis.createClient();
var moment = require('moment');
const momFmt = 'YY-MM-DD hh:mm:ss';

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

//
// Fetch GHG Emissions Norway
//
function goFetch() {
  function status(response) {
    if (response.status >= 200 && response.status < 300) {
      return Promise.resolve(response)
    } else {
      return Promise.reject(new Error(response.statusText))
    }
  }
  function json(response) {
    return response.json()
  }
  fetch('https://data.ssb.no/api/v0/no/table/08940', {
    method: 'post',
    body: '{"query":[{"code":"UtslpTilLuft","selection":{"filter":"vs:UtslpKildeA01","values":["0"]}},{"code":"UtslpKomp","selection":{"filter":"all","values":["*"]}},{"code":"ContentsCode","selection":{"filter":"item","values":["UtslippCO2ekvival"]}}],"response":{"format":"json-stat2"}}'
  })
    .then(status)
    .then(json)
    .then(results => {
      let res = {
        source: 'Statistics Norway, https://ssb.no',
        updated: results.updated,
        license: 'Norwegian License for Open Government Data (NLOD) 2.0, http://data.norge.no/nlod/en/2.0',
        link: 'https://data.ssb.no/api/v0/',
        info: 'Data is in 1000 tons CO2 Equivalents per year',
        data: []
      };
      // Number of values per component (one value for each year)
      let numValues = results.size[results.size.length - 1];
      // Get the list of years in the dataset
      let years = Object.values(results.dimension.Tid.category.label);
      if (years.length !== numValues) {
        console.log('Error: SSB numVal<>years', numValues, years)
      }
      // Get the dataset-category names (i.e. pollutant names)
      // Change the long norwegian strings to shorter english-sounding ones
      let pollutants = Object.values(results.dimension.UtslpKomp.category.label);
      for (let i = 0; i < pollutants.length; i++) {
        if (pollutants[i].indexOf('i alt') !== -1) pollutants[i] = 'Total';
        if (pollutants[i].indexOf('CO2') !== -1) pollutants[i] = 'CO2';
        if (pollutants[i].indexOf('CH4') !== -1) pollutants[i] = 'CH4';
        if (pollutants[i].indexOf('N2O') !== -1) pollutants[i] = 'N2O';
        if (pollutants[i].indexOf('HFK') !== -1) pollutants[i] = 'HFC';
        if (pollutants[i].indexOf('PFK') !== -1) pollutants[i] = 'PFC';
        if (pollutants[i].indexOf('SF6') !== -1) pollutants[i] = 'SF6';
      }
      // Step through list of values
      // Break it down into one list per pollutant
      // Create list per pollutant [ { year, value }, {}, ...]
      for (let i = 0; i < results.value.length; i += numValues) {
        let annualValues = [];
        for (let j = 0; j < numValues; j++) {
          annualValues.push({
            t: years[j],
            y: results.value[i + j]
          })
        }
        res.data.push({
          name: pollutants.shift(),
          values: annualValues
        });
      }
      // Store key/value pair to Redis
      let redisKey = 'emissions-norway';
      let redisValue = JSON.stringify(res);
      console.log(moment().format(momFmt) +
        ' Storing ' + redisValue.length +
        ' bytes, key=' + redisKey +
        ' value=' + redisValue.substring(0, 60));

      redClient.set(redisKey, redisValue, function (error, result) {
        if (result) {
          console.log(moment().format(momFmt) + ' Result:' + result);
        }
        else {
          console.log(moment().format(momFmt) + ' Error: ' + error);
        }
      });
      // This next one is terrible. I am ashamed, but I need a way to terminate this program
      // The Node event loop should be empty, so Node should exit automatically, 
      // but there is something about this fetch() not quite being done:
      setInterval((() => {
        process.exit();
      }), 2000);
    })
    .catch(err => console.log(err));
}

goFetch();
