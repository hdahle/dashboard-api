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
