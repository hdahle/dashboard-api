
var http = require('http');
var https = require('https');
var url = require('url');
var fs = require('fs');
var redis = require('redis');
var redClient = redis.createClient();
var moment = require('moment');

redClient.on('connect', function () {
  console.log('[co2] redis client connected');
});

redClient.on('ready', function () {
  console.log('[co2] redis client ready');
});

redClient.on('warning', function () {
  console.log('[co2] redis warning');
});

redClient.on('error', function (err) {
  console.log('[co2] redis error:' + err);
});

/*
var httpsOptions = {
    key: fs.readFileSync('/home/bitnami/projects/https-server/server.key'),
    cert: fs.readFileSync('/home/bitnami/projects/https-server/server.crt'),
    rejectUnauthorized: false,
    agentOptions: {
        checkServerIdentity: function () { }
    }
};
*/

var keys = [
  {
    path: "/emissions-norway", key: "emissions-norway"
  },
  {
    path: "/test", key: "test"
  }
];

//https.createServer(httpsOptions, function (req, res) {
http.createServer(function (req, res) {
  var path = url.parse(req.url).pathname;
  var query = url.parse(req.url).query;
  console.log(moment().format('HH:mm:ss') + ' Query: ' + query + ' Path: ' + path);

  if (path === '/favicon.ico') {
    // The favicon handler is inspired by
    //   https://stackoverflow.com/questions/15463199/how-to-set-custom-favicon-in-express
    // To make an icon:        http://www.favicon.cc/
    // To convert to base64:   http://base64converter.com/
    const favicon = new Buffer.from(
      'AAABAAEAEBAQAAEABAAoAQAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAgAAAAAAAAAAAAAAAE' +
      'AAAAAAAAAC9bEsAAAAAAEGwIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' +
      'AAAAAAAAAAAAAAAAAAAAAAERERERERERESIiIiIiIiIRIREREREREREhABABABABESEAEAEAE' +
      'AERIQAQAQAQAREhABABABABESEAEAEAERERIQAQAQAREREhABABABERESEAEAEAERERIREQAQ' +
      'AREREhERABERERESEREAERERERIREQARERERERERERERERH//wAAgAEAAL//AACkkwAApJMAA' +
      'KSTAACkkwAApJ8AAKSfAACknwAApJ8AALyfAAC8/wAAvP8AALz/AAD//wAA', 'base64');

    res.setHeader('Content-Length', favicon.length);
    res.setHeader('Content-Type', 'image/x-icon');
    res.setHeader("Cache-Control", "public, max-age=2592000");                // expires after a month
    res.setHeader("Expires", moment().add(1, 'months').format('YYYY-MM-DD'));
    res.end(favicon);
    return;
  }

  // This is for the standard case. Write some headers first
  res.writeHead(200, {
    'Content-Type': 'text/plain',
    'Access-Control-Allow-Origin': '*'
  });
  // The path part should not be empty
  if (path === undefined || path === null || path.length === 0) {
    console.log(moment().format('hh:mm:ss') + ' Error: empty path');
    res.write('Error: empty path');
    res.end('\n');
    return;
  }


  let index = keys.findIndex(x => x.path === path);
  if (index !== -1) {
    redClient.get(keys[index].key, function (error, result) {
      if (result) {
        console.log(moment().format('hh:mm:ss') + ' result:' + result.substring(0, 60));
        res.write(result);
        res.end('\n');
      }
      else {
        console.log(moment().format('hh:mm:ss') + ' no result in redis');
        res.write('error');
        res.end('\n');
      }
    });

  }
  else {
    // Incorrect path
    console.log("Error: invalid path", path, query);
    res.write("Error: invalid path");
    res.end('\n');
  }


}).listen(80);
