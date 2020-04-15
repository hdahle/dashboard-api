# Power consumption in Spain
This connector uses the public API of the Spanish grid operator.
### The REST URL
````
let url = 'https://apidatos.ree.es/en/datos/demanda/evolucion?start_date='
  + year + '-01-01&end_date='
  + (1 + year) + '-01-01&time_trunc=day';
````
With this URL we request data from ree.es:
````
  fetch(url)
    .then(status)
    .then(json)
    .then(results => {
      let d = results.included[0].attributes.values;
      d = d.map(x => ({
        t: moment(x.datetime).format('MM-DD'),
        y: Math.floor(x.value / 100) / 10
      }))
      let val = JSON.stringify({
        source: 'Red Electrica de Espana, https://www.ree.es/en',
        link: 'https://apidatos.ree.es',
        info: 'Daily electricity demand in Spain, measured in GWh',
        accessed: moment().format(momFmt),
        year: year,
        units: 'GWh',
        data: d
      });
````
Some stuff removed, but that's it really. Then store to Redis.
### Issues
Just getting the data for the current year will of course fail to work well after the end of this year.
### Important
Sometimes the API server returns 500 and we have to retry. Part of this seems to be the server pacing requests, but sometimes it happens even after a long wait.
