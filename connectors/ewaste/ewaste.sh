#!/bin/sh
redis-cli -x set globalewaste-2020 < globalewaste.json
redis-cli get globalewaste-2020 | jq .

