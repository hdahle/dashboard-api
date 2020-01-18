/*
 * A simple server for various climate data
 *
 * Copyright H. Dahle, 2019
 */

var http = require('http');
var https = require('https');
var url = require('url');
var fs = require('fs');
var redis = require('redis');
var redClient = redis.createClient();

var moment = require('moment');

redClient.on('connect', function() {
    console.log('[co2] redis client connected');
});

redClient.on('ready', function() {
    console.log('[co2] redis client ready');
});

redClient.on('warning', function() {
    console.log('[co2] redis warning');
});

redClient.on('error', function(err) {
    console.log('[co2] redis error:' + err);
});

var httpsOptions = {
    key: fs.readFileSync('/home/bitnami/projects/https-server/server.key'),
    cert:fs.readFileSync('/home/bitnami/projects/https-server/server.crt'),
    rejectUnauthorized: false,
    agentOptions: {
        checkServerIdentity: function(){}
    }
};

var keys = [
    {
        path: "/emissions-norway",
        key: "emissions-norway"
    },
    {
        path: "/ozone",
        key: "ozone"
    },
    {
        path: "/operational-ccs",
        key: "operational-ccs"
    },
    {
        path: "/temperature-svalbard",
        key: "temperature-svalbard"
    },
    {
        path: "/CSIRO_Recons",
        key: "CSIRO_Recons"
    },
    {
        path: "/CSIRO_Alt_yearly",
        key: "CSIRO_Alt_yearly"
    },
    {
        path: "/birkenes-co2-2009-2019",
        key: "birkenes-co2-2009-2019"
    },
    {
        path: "/birkenes-monthly",
        key: "birkenes-monthly"
    },
    {
        path: "/eia-international-data-dry-natural-gas-production",
        key: "eia-international-data-dry-natural-gas-production"
    },
    {
        path: "/eia-international-data-oil-production",
        key: "eia-international-data-oil-production"
    },
    {
        path: "/eia-international-data-coal",
        key: "eia-international-data-coal"
    },
    {
        path: "/eia-international-data-oil",
        key: "eia-international-data-oil"
    },
    {
        path: "/WPP2019_TotalPopulationByRegion",
        key: "WPP2019_TotalPopulationByRegion"
    },
    {
        path: "/WPP2019_TotalPopulationByRegionXY",
        key: "WPP2019_TotalPopulationByRegionXY"
    },
    {
        path: "/vostok-and-maunaloa",
        key: "vostok-and-maunaloa"
    },
    {
        path: "/co-emissions-per-capita",
        key: "co-emissions-per-capita"
    },
    {
        path: "/vostok-icecore-co2",
        key: "vostok-icecore-co2"
    },
    {
        path: "/ice-nsidc",
        key: "ice-nsidc"
    },
    {
        path: "/queimadas",
        key: "queimadas"
    },
    {
        path: "/temperature-anomaly",
        key: "temperature-anomaly"
    },
    {
        path: "/annual-co-emissions-by-region",
        key: "annual-co-emissions-by-region"
    },
    {
        path: "/maunaloa-ch4",
        key: "maunaloach4"
    },
    {
        path: "/maunaloa-co2",
        key: "maunaloaco2"
    },
    {
        path: "/ch4",
        key: "maunaloach4"
    },
    {
        path: "/co2",
        key: "maunaloaco2"
    }
];

https.createServer(httpsOptions, function (req, res) {
    var path = url.parse(req.url).pathname;
    var query = url.parse(req.url).query;
    console.log(moment().format('HH:mm:ss')+ ' Query: ' + query + ' Path: ' + path);

    if (path === '/favicon.ico') {
        // The favicon handler is inspired by
        //   https://stackoverflow.com/questions/15463199/how-to-set-custom-favicon-in-express
        // To make an icon:        http://www.favicon.cc/
        // To convert to base64:   http://base64converter.com/
        const favicon = new Buffer.from('AAABAAEAEBAQAAEABAAoAQAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAgAAAAAAAAAAAA
AAAE' +
                                        'AAAAAAAAAC9bEsAAAAAAEGwIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAA' +
                                        'AAAAAAAAAAAAAAAAAAAAAAERERERERERESIiIiIiIiIRIREREREREREhABABABABESEAE
AEAE' +
                                        'AERIQAQAQAQAREhABABABABESEAEAEAERERIQAQAQAREREhABABABERESEAEAEAERERIR
EQAQ' +
                                        'AREREhERABERERESEREAERERERIREQARERERERERERERERH//wAAgAEAAL//AACkkwAAp
JMAA' +
                                        'KSTAACkkwAApJ8AAKSfAACknwAApJ8AALyfAAC8/wAAvP8AALz/AAD//wAA', 'base64
');
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


    let index = keys.findIndex(x => x.path===path);
    if (index !== -1) {
        redClient.get(keys[index].key, function(error, result) {
            if (result) {
                console.log(moment().format('hh:mm:ss') + ' result:' + result.substring(0,60));
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


}).listen(4438);
