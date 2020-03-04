// eia-gdp-pop-co2.js
//
// Pre-requisites: 
//   eia-global-emissions
//   eia-global-gdp
//   eia-global-population
//
// Fetches the three data-series from API-server,
// merges them into a single data-series, so that
// GDP/POP/CO2 can be displayed in a single bubble chart
//
// H. Dahle, 2020

var fetch = require('node-fetch');
var redis = require('redis');
var redClient = redis.createClient();
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
const momFmt = 'YY-MM-DD hh:mm:ss';
const redisKey = 'eia-global-gdp-pop-co2';

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

function eiaGdpPopCo2() {
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

  // process commandline
  let scope = argv.scope; // coal, oil or gas
  let reg = argv.region; // any of eiaRegions

  const eiaRegions = [
    'AFRC', 'WORL', 'EURO', 'EURA', 'MIDE', 'ASOC', 'ASIA', 'OCEA', 'CSAM', 'NOAM'
  ];

  // make sure command-line ARGS are good
  if (scope === undefined || !['world', 'country'].includes(scope) || ((scope === 'country') && !eiaRegions.includes(reg))) {
    console.log('Usage: node eia.js --scope [world|countries] --region <region>');
    console.log('  world: merge data on a per region level (AFRC/EURO/NOAM...)');
    console.log('  country: merge data on a per country level')
    let s = '';
    eiaRegions.forEach(r => s += r + ' ')
    console.log('  <region> is one of ', s)
    process.exit();
  }

  let urlSuffix = '';
  if (scope === 'country') {
    urlSuffix = '-' + reg;
  }

  let url = 'https://api.dashboard.eco/eia-global-gdp' + urlSuffix;
  fetch(url)
    .then(status)
    .then(json)
    .then(gdp => {
      //console.log(url, gdp);
      url = 'https://api.dashboard.eco/eia-global-population' + urlSuffix;
      fetch(url)
        .then(status)
        .then(json)
        .then(pop => {
          //console.log(url, pop)
          url = 'https://api.dashboard.eco/eia-global-emissions' + urlSuffix;
          fetch(url)
            .then(status)
            .then(json)
            .then(co2 => {
              //console.log(url, co2)
              // this is the master list, a merge of GDP, CO2 and POP
              // list = [ { region:r, data:[{year, gdp}] }]
              let list = [];
              // do GDP first: master.data = [{year, gdp}, {}, ...]
              gdp.series.forEach(region => {
                list.push({
                  region: region.region,
                  data: region.data.map(d => ({
                    year: d.x,
                    gdp: d.y
                  }))
                })
              });
              // merge POP: master = [{year, gdp, pop}, {}, ...] 
              pop.series.forEach(x => {
                list.forEach(region => {
                  if (region.region === x.region) {
                    region.data.forEach(d => {
                      let tmp = x.data.find(x => x.x === d.year)
                      d.pop = (tmp === undefined) ? null : tmp.y;
                    });
                  }
                })
              });
              // merge POPULATION
              co2.series.forEach(x => {
                list.forEach(region => {
                  if (region.region === x.region) {
                    region.data.forEach(d => {
                      let tmp = x.data.find(x => x.x === d.year);
                      d.co2 = (tmp === undefined) ? null : tmp.y;
                    });
                  }
                })
              });
              //console.log(list)
              let results = {
                source: co2.source,
                link: co2.link,
                accessed: co2.accessed,
                license: 'From https://www.eia.gov/about/copyrights_reuse.php: U.S. government publications are in the public domain and are not subject to copyright protection. You may use and/or distribute any of our data, files, databases, reports, graphs, charts, and other information products that are on our website or that you receive through our email distribution service. However, if you use or reproduce any of our information products, you should use an acknowledgment, which includes the publication date',
                info: 'Units: Population - thousands, CO2 - million metric tons, GDP - million US dollars PPP',
                data: list
              };

              // Store key/value pair to Redis
              let redisValue = JSON.stringify(results);
              console.log(moment().format(momFmt) +
                ' Storing ' + redisValue.length +
                ' bytes, key=' + redisKey + urlSuffix +
                ' value=' + redisValue.substring(0, 60));

              redClient.set(redisKey + urlSuffix, redisValue, function (error, result) {
                if (result) {
                  console.log(moment().format(momFmt) + ' Result:' + result);
                } else {
                  console.log(moment().format(momFmt) + ' Error: ' + error);
                }
              });

              // exit
              setInterval((() => {
                process.exit();
              }), 1000)

            })
            .catch(error => {
              console.log(error.message);
              setInterval((() => { process.exit(); }), 1000)
            })
        })
        .catch(error => {
          console.log(error.message);
          setInterval((() => { process.exit(); }), 1000)
        })
    })
    .catch(error => {
      console.log(error.message);
      setInterval((() => { process.exit(); }), 1000)
    })
}

eiaGdpPopCo2();
