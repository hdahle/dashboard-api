# Traffic data from www.vegvesen.no

This connector compares traffic (vehicles per hour) for the last 90 days with the same time period a year ago, in order to illustrate the impact of Corona-virus lockdown.

### The API
The API is documented here: 
https://www.vegvesen.no/trafikkdata/start/om-api

### GraphQL
The API uses GraphQL for queries

````
 // This is a GraphQL query 
  fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      query: '{ trafficData(trafficRegistrationPointId: \"' + stationID + '\") ' +
        '{ volume ' +
        '{ byDay(from: \"' + fromDate + 'T00:00:00+02:00\", to: \"' + toDate + 'T00:00:00+02:00\")' +
        '{ edges' +
        '{ node' +
        '{ from to total' +
        '{ volumeNumbers' +
        '{ volume }}}}}}}}"'
    })
  })
````
Once we've sorted the query, the rest is standard:
````
    .then(status)
    .then(json)
    .then(res => {
      // time-data is in YYYY-MM-DDTHH:MM+02:00 format
      // we want to simplify to MM-DD
      // however we need to stay in the same timezone, so we use moment.parseZone()
      let d = res.data.trafficData.volume.byDay.edges.map(e => ({
        t: moment.parseZone(e.node.from).format('MM-DD'),
        y: e.node.total.volumeNumbers ? e.node.total.volumeNumbers.volume : null
      }));
````
Then just save it to Redis.


Can't get pagination to work though.
