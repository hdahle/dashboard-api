# dashboard-api
API server for the dashboard-frontend project

A simple node.js server fronts a Redis cache

A number of scripts fetches data from third party sources, formats the data into some reasonable JSON format, and populates the Redis cache from time to time

The server listens on ports 80 and 443. Remember to use the "sudo setcap" in order to allow node permissions for 80 and 443.

