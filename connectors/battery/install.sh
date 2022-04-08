#!/bin/sh
redis-cli -x set bloomberg-battery < bloomberg-battery.json
redis-cli get bloomberg-battery | jq .

