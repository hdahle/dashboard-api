//
// Script that fetches annual GHG Emissions data from Norway's DATA.SSB.NO
// Convert dataset into a more useful JSON object
// JSON to be stored in the api-server's Redis db
// JSON object should be easy to plot using chart.js
//

var fetch = require('node-fetch');
var redis = require('redis');
var moment = require('moment');
const momFmt = 'YY-MM-DD hh:mm:ss';

function redisSave(redisKey, redisVal) {
  let redClient = redis.createClient();

  redClient.on('connect', function () {
    console.log(moment().format(momFmt) + ' Redis client connected');
  });
  redClient.on('ready', function () {
    console.log(moment().format(momFmt) + ' Redis client ready');
    
    redClient.set(redisKey, redisVal, function (error, result) {
      if (result) {
        console.log(moment().format(momFmt) + ' Result:' + result);
      }
      else {
        console.log(moment().format(momFmt) + ' Error: ' + error);
      }
    });
    redClient.quit();
  });
  redClient.on('warning', function () {
    console.log(moment().format(momFmt) + ' Redis warning');
  });
  redClient.on('error', function (err) {
    console.log(moment().format(momFmt) + ' Redis error:' + err);
    console.log(redisVal)
    redClient.quit();
  });
}


//
// Fetch GHG Emissions Norway
//
(() => {
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
        info: 'Units: million tons CO2 equivalents per year',
        data: {
          datasets: [],
          yAxisLabel: 'Mt'
        }
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
            x: parseInt(years[j], 10), 
            y: results.value[i + j] / 1000
          })
        }
        res.data.datasets.push({
          label: pollutants.shift(),
          data: annualValues
        });
      }
      // Store key/value pair to Redis
      const redisKey = 'ghg-norway';
      const redisVal = JSON.stringify(res);
      console.log(moment().format(momFmt) + ' Bytes: ' + redisVal.length + ' Key=' + redisKey + ' Value=' + redisVal.substring(0, 60));
      redisSave(redisKey, redisVal);
    })
    .catch(err => console.log(err));
})();
