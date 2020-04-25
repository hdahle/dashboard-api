#!/bin/sh

curl -l -X GET \
  -H "ResourceVersion: v4" \
  -H "app_id: 1f43c9a0" \
  -H "accept: application/json" \
  -H "app_key: f93652e497931f91fd0d5ec87f2ee03a" \
  "https://api.schiphol.nl/public-flights/flights"


