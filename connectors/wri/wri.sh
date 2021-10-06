#!/bin/sh
redis-cli -x set wri-2016 < wri.json
redis-cli get wri-2016 | jq .
