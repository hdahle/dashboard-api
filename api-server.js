//
// A super-simple node.js HTTP(S) API-server using a Redis-cache
//
// H Dahle
//
var http = require('http');
var https = require('https');
var fs = require('fs');
var redis = require('redis');
var redClient = redis.createClient();

redClient.on('connect', function () {
  console.log('Redis client connected');
});

redClient.on('ready', function () {
  console.log('Redis client ready');
});

redClient.on('warning', function () {
  console.log('Redis warning');
});

redClient.on('error', function (err) {
  console.log('Redis error:' + err);
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
  console.log('Warning: Not starting HTTPS server. Cert not found');
}

// Listen on HTTP Port 80 also
http.createServer(requestListener).listen(80);

// A single requestListener for both HTTP and HTTPS
// The old way of doing this was:
// let path = url.parse(req.url).pathname;
// let query = url.parse(req.url).query;
// However we're not using the query part anyway so the URL module is overkill (and has bugs)
function requestListener(req, res) {
  console.log(req.url, req.url.length, req.headers.host);
  // Always write some headers first
  res.writeHead(200, {
    'Content-Type': 'text/plain',
    'Access-Control-Allow-Origin': '*'
  });
  // req.url should not be empty, so this code will never execute
  if (req.url === undefined || req.url === null || req.url.length === 0) {
    console.log('impossible');
    res.write('impossible');
    res.end('\n');
    return;
  }
  // This is where I could serve index.html...
  if (req.url === '/') {
    res.write('null');
    res.end('\n');
    return;
  }
  // Look up key (req.url) in Redis after removing leading '/', write
  redClient.get(req.url.substr(1), function (error, result) {
    if (result) {
      console.log('OK', result.substring(0, 50));
      res.write(result);
    }
    res.end('\n');
  });
}
