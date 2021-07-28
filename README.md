# dashboard-api

## API server for the dashboard-frontend project
A simple node.js server fronts a Redis cache and provides an HTTP(S) API.

A number of scripts fetches data from third party sources, formats the data into some reasonable JSON format, and populates the Redis cache from time to time (depending on how often the third parties update their data)

The server listens on ports 80 and 443. Remember to use the "sudo setcap" in order to allow node permissions for 80 and 443:

On Ubuntu/WSL2: 
```shell
sudo setcap "cap_net_bind_service=+ep" /home/hd/.nvm/versions/node/v13.5.0/bin/node
```
On Ubuntu/Bitnami:
```shell
sudo setcap "cap_net_bind_service=+ep" /opt/bitnami/nodejs/bin/.node.bin
```

Make sure to stop Apache, you don't want both Apache and node trying to serve ports 80 and 443:
```shell
sudo mv /opt/bitnami/apache2/scripts/ctl.sh /opt/bitnami/apache2/scripts/ctl.sh.disabled
```

## Certificate access for node.js process
It's a good idea to verify that the certificate.key-file is readable by the node.js process, otherwise node will only start HTTP and not HTTPS. On Ubuntu/Bitnami the certs are in ```/opt/bitnami/letsencrypt/certificates``` - check the permissions on the *key* file. If necessary, create a group of users (node.js process owner + root) and give ownership of the *key* file to that group. Make sure that permissions survive after the cron-job renews certificates.

Top tip: It could be a good idea to tell PM2 to ```--watch``` the certificate so that it restarts the process whenever the cert updates.

## Connectors
The connectors are several 'micro-services'. There is one connector for each third party data source. Each connector runs as a Cron-job. There should be an install.sh script in each connector folder which adds the connector-script to crontab (while trying to take care to avoid adding duplicate crontab-entries, you should be able to run install as many times as you like). Also, some effort has gone into makeing sure that appropriate TMP-file directories are used and that executables used in crontab-entries have full path names. Path names for executables such as redis-cli varies between WSL/Ubuntu and Lightsail/Bitnami/Ubuntu which are the two platforms this is tested on.
