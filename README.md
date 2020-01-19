# dashboard-api
API server for the dashboard-frontend project

A simple node.js server fronts a Redis cache and provides an HTTP(S) API.

A number of scripts fetches data from third party sources, formats the data into some reasonable JSON format, and populates the Redis cache from time to time.

The server listens on ports 80 and 443. Remember to use the "sudo setcap" in order to allow node permissions for 80 and 443:

On WSL2: 

sudo setcap "cap_net_bind_service=+ep" /home/hd/.nvm/versions/node/v13.5.0/bin/node

On Ubuntu/Bitnami:

sudo setcap "cap_net_bind_service=+ep" /opt/bitnami/nodejs/bin/.node.bin

It's also a good idea to stop Apache from running.

It's a good idea to verify that the certificate.key-file is readable by the node process. On Ubuntu/Bitnami the certs are in /opt/bitnami/letsencrypt/certificates - check the permissions on the *key* file. If necessary, create a group of users (bitnami + root) and give ownership of the *key* file to that group. Make sure that permissions survice after the cron-job renews certificates.
