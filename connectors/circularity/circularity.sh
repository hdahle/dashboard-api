#!/bin/sh

redis-cli -x set circularity-2020 < circularity.json 

redis-cli get circularity-2020 | jq

