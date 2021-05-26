#!/bin/sh
redis-cli -x set plastic-waste-2016 < plastic-waste.json
redis-cli get plastic-waste-2016 | jq .
