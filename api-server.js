//
// A super-simple node.js API-server
// Should have used Express actually
// Should have used some debug framework and not console.log
// Should have done a lot of things...
//
var http = require('http');
var https = require('https');
var url = require('url');
var fs = require('fs');
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

// For the certificate stuff
const keyFile = '/home/bitnami/stack/apache2/conf/server.key';
const crtFile = '/home/bitnami/stack/apache2/conf/server.crt';

// Mapping from query path to redis-key
var keys = [
  { path: '/emissions-norway', key: 'emissions-norway' },
  { path: '/test', key: 'test' }
];

// Listen for HTTPS on port 443 only if KEY and CERT exists
if (fs.existsSync(keyFile) && fs.existsSync(crtFile)) {
  var httpsOptions = {
    key: fs.readFileSync(keyFile),
    cert: fs.readFileSync(crtFile),
    rejectUnauthorized: false,
    agentOptions: {
      checkServerIdentity: function () { }
    }
  };
  https.createServer(httpsOptions, listenerFunction).listen(443);
} else {
  console.log(moment().format(momFmt) + ' Not starting HTTPS server. Cert not found');
}

// Listen on HTTP Port 80
http.createServer(listenerFunction).listen(80);

// The server that works for both HTTP and HTTPS
function listenerFunction(req, res) {
  var path = url.parse(req.url).pathname;
  var query = url.parse(req.url).query;
  console.log(moment().format(momFmt) + ' Query:' + query + ' Path:' + path);

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
    res.setHeader('Cache-Control', 'public, max-age=2592000');// expires after a month
    res.setHeader('Expires', moment().add(1, 'months').format('YYYY-MM-DD'));
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
    console.log(moment().format(momFmt) + ' Error: empty path');
    res.write('Error: empty path');
    res.end('\n');
    return;
  }
  let index = keys.findIndex(x => x.path === path);
  if (index !== -1) {
    redClient.get(keys[index].key, function (error, result) {
      if (result) {
        console.log(moment().format(momFmt) + ' Result:' + result.substring(0, 60));
        res.write(result);
        res.end('\n');
      }
      else {
        console.log(moment().format(momFmt) + ' Error: no result in redis');
        res.write('Error: no result at that path');
        res.end('\n');
      }
    });
  }
  else {
    // Incorrect path
    console.log(moment().format(momFmt) + ' Error: invalid path', path, query);
    res.write('Error: invalid path');
    res.end('\n');
  }
}
