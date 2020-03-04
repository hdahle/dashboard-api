// eia-all-countries.js
//
// Fetches data from api.eia.gov
// Fetches all countries from all global regions
// Reult from EIA is JSON, but we convert to chart.js-friendly format
//
// H. Dahle, 2020

var fetch = require('node-fetch');
var redis = require('redis');
var redClient = redis.createClient();
var moment = require('moment');
var argv = require('minimist')(process.argv.slice(2));
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

// Fetch EIA data
function main() {
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
  let apiKey = argv.apikey; // filename from cmd line
  let redisKey = argv.key; // redis-key from cmd line
  let series = argv.series; // coal, oil or gas

  // These are the regions we query for
  const eiaRegions = [
    { region: 'Africa', c: 'AFRC', code: 'AFRC+AGO+BDI+BEN+BFA+BWA+CAF+CIV+CMR+COD+COG+COM+CPV+DJI+DZA+EGY+ERI+ESH+ETH+GAB+GHA+GIN+GMB+GNB+GNQ+KEN+LBR+LBY+LSO+MAR+MDG+MLI+MOZ+MRT+MUS+MWI+NAM+NER+NGA+REU+RWA+SDN+SEN+SHN+SLE+SOM+SSD+STP+SWZ+SYC+TCD+TGO+TUN+TZA+UGA+ZAF+ZMB+ZWE' },
    { region: 'World', c: 'WORL', code: 'WORL' },
    { region: 'Europe', c: 'EURO', code: 'EURO+ALB+AUT+BEL+BGR+BIH+CHE+CSK+CYP+CZE+DDR+DEU+DEUW+DNK+ESP+FIN+FRA+FRO+GBR+GIB+GRC+HRV+HUN+IRL+ISL+ITA+LTU+LUX+MKD+MLT+MNE+NLD+NOR+POL+PRT+ROU+SCG+SRB+SVK+SVN+SWE+TUR+UNK+YUG' },
    { region: 'Middle East', c: 'MIDE', code: 'MIDE+ARE+BHR+IRN+IRQ+ISR+JOR+KWT+LBN+OMN+PSE+QAT+SAU+SYR+YEM' },
    { region: 'Eurasia', c: 'EURA', code: 'EURA+ARM+AZE+BLR+EST+GEO+KAZ+KGZ+LVA+MDA+RUS+SUN+TJK+TKM+UKR+UZB' },
    { region: 'Asia&Oceania', c: 'ASOC', code: 'ASOC+AFG+ASM+AUS+BGD+BRN+BTN+CHN+COK+FJI+GUM+HITZ+HKG+IDN+IND+JPN+KHM+KIR+KOR+LAO+LKA+MAC+MDV+MMR+MNG+MNP+MYS+NCL+NIU+NPL+NRU+NZL+PAK+PHL+PNG+PRK+PYF+SGP+SLB+THA+TLS+TON+TWN+USIQ+VNM+VUT+WAK+WSM' },
    { region: 'Asia', c: 'ASIA', code: 'AFG+BGD+BRN+BTN+CHN+HKG+IDN+IND+JPN+KHM+KOR+LAO+LKA+MAC+MDV+MMR+MNG+MYS+NPL+PAK+PHL+SGP+THA+TLS+TWN+VNM' },
    { region: 'Oceania', c: 'OCEA', code: 'ASM+AUS+COK+FJI+GUM+HITZ+KIR+MAC+MNP+NCL+NIU+NPL+NRU+NZL+PNG+PYF+SLB+TON+USIQ+VUT+WAK+WSM' },
    { region: 'S America', c: 'CSAM', code: 'CSAM+ABW+ARG+ATA+ATG+BHS+BLZ+BOL+BRA+BRB+CHL+COL+CRI+CUB+CYM+DMA+DOM+ECU+FLK+GLP+GRD+GTM+GUF+GUY+HND+HTI+JAM+KNA+LCA+MSR+MTQ+NIC+NLDA+PAN+PER+PRI+PRY+SLV+SUR+TCA+TTO+URY+VCT+VEN+VGB+VIR' },
    { region: 'N America', c: 'NOAM', code: 'NOAM+BMU+CAN+GRL+MEX+SPM+USA+USOH' },
  ];

  // Series names and appropriate units for series
  const eiaSeries = {
    'coal': { eiaSeriesName: 'INTL.7-1-', eiaUnit: 'MT.A' },
    'oil': { eiaSeriesName: 'INTL.55-1-', eiaUnit: 'TBPD.A' },
    'gas': { eiaSeriesName: 'INTL.26-1-', eiaUnit: 'BCM.A' },
    'population': { eiaSeriesName: 'INTL.4702-33-', eiaUnit: 'THP.A' },
    'emissions': { eiaSeriesName: 'INTL.4008-8-', eiaUnit: 'MMTCD.A' },
    'nuclear': { eiaSeriesName: 'INTL.27-12-', eiaUnit: 'BKWH.A' },
    'gdp': { eiaSeriesName: 'INTL.4701-34-', eiaUnit: 'BDOLPPP.A' }
  };

  // make sure command-line ARGS are good
  if (apiKey === undefined || redisKey === undefined || series === undefined || eiaSeries[series] === undefined) {
    console.log('Usage: node eia.js --series <seriesname> --apikey <apikey> --key <rediskey>');
    let s = '';
    Object.keys(eiaSeries).forEach(x => s += x + ' ');
    console.log('  <seriesname> is one of: ', s);
    s = '';
    eiaRegions.forEach(r => s += '-' + r.c + ' ');
    console.log('  <rediskey> is the prefix to which will be added ', s);
    console.log('  A total of ', eiaRegions.length, ' key/value pairs will be stored');
    process.exit();
  }

  // create a query URL per region, the EIA API supports max 100 series (countries) per request URL
  eiaRegions.forEach(element => {
    let { eiaSeriesName, eiaUnit } = eiaSeries[series];
    let url = 'https://api.eia.gov/series/?api_key=' + apiKey + '&series_id=';
    let countries = element.code.split('+');
    countries.forEach(c => {
      url += eiaSeriesName + c + '-' + eiaUnit + ';';
    })

    // now go get the data for each region
    fetch(url)
      .then(status)
      .then(json)
      .then(results => {
        // results.series is undefined if incorrect query URL
        if ((results.series === undefined) || (results.series.length === 0) ||
          (results.series[0].data === undefined) || (results.series[0].data.length === 0)) {
          console.log('No data from api.eia.gov: ', results, url);
          process.exit();
        }

        // original EIA data array is:   [ [year,value], [], ...]
        // convert to chart.js-friendly: [ {year,value}, {}, ...]
        results.series.forEach(series => {
          let d = series.data;
          series.data = d.map(x => ({
            x: parseInt(x[0], 10),
            y: Math.round(x[1] * 100) / 100
          }));
        })

        // add 'source', 'link', 'accessed' key/values to JSON 
        // this is so that website can display this autmatically
        results.link = 'https://www.eia.gov/opendata/qb.php';
        results.source = results.series[0].source;
        results.accessed = results.series[0].updated;

        // Store key/value pair to Redis
        let redisValue = JSON.stringify(results);
        console.log(moment().format(momFmt) + ' Store ' + redisValue.length + 'b, key=' + redisKey + '-' + element.c);
        redClient.set(redisKey + '-' + element.c, redisValue, function (error, result) {
          if (result) {
            console.log(moment().format(momFmt) + ' Result:' + result);
          } else {
            console.log(moment().format(momFmt) + ' Error: ' + error);
          }
        });
      })
      .catch(err => console.log(err))
  });
  // a disgraceful exit
  // it would be better to wait for all fetch-promises to complete...
  setInterval((() => {
    process.exit();
  }), 10000)
}


main();