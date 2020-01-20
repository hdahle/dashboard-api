//
// A super-simple node.js API-server
// Should have used Express actually
// Should have used some debug framework and not console.log
// Should have done a lot of things...
// Most important todo: use mocha for testing
//
// H Dahle
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
const keyFile = '/opt/bitnami/letsencrypt/certificates/api.dashboard.eco.key';
const crtFile = '/opt/bitnami/letsencrypt/certificates/api.dashboard.eco.crt';

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
  https.createServer(httpsOptions, requestListener).listen(443);
} else {
  console.log(moment().format(momFmt), 'Warning: Not starting HTTPS server. Cert not found');
}

// Listen on HTTP Port 80
http.createServer(requestListener).listen(80);

// A single requestListener for both HTTP and HTTPS
function requestListener(req, res) {
  let path = url.parse(req.url).pathname;
  let query = url.parse(req.url).query;
  let dbgMsg = {
    status: 'Error',
    result: '',
    time: moment().format(momFmt)
  };
  console.log(dbgMsg.time, 'Query:' + query, 'Path:' + path, 'Host:', req.headers.host);
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
    dbgMsg.result = 'empty path';
    console.log(dbgMsg.time, dbgMsg.status, dbgMsg.result);
    res.write(JSON.stringify(dbgMsg));
    res.end('\n');
    return;
  }

  // This is where I could serve index.html...
  if (path === '/') {
    res.write('root');
    res.end('\n');
    return;
  }

  // Look up path in Redis after removing leading '/', write
  redClient.get(path.substr(1), function (error, result) {
    if (result) {
      dbgMsg.status = 'OK';
      dbgMsg.result = result.substring(0, 50);
      res.write(result);
    }
    else {
      dbgMsg.status = 'Error';
      dbgMsg.result = 'nothing in db';
      res.write(JSON.stringify(dbgMsg));
    }
    res.end('\n');
    console.log(dbgMsg.time, dbgMsg.status, dbgMsg.result);
  });
}
