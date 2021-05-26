#!/bin/sh
redis-cli -x set irena-2020 < irena.json
redis-cli get irena-2020 | jq .
