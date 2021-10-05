#!/bin/sh
redis-cli -x set irena-2020 < irena.json
redis-cli get irena-2020 | jq .
redis-cli -x set irena-2021 < irena-2021.json
redis-cli get irena-2021 | jq .
