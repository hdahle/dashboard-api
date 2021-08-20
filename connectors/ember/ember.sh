#!/bin/sh

# curl "https://ember-climate.org/wp-content/uploads/2021/03/Data-Global-Electricity-Review-2021.xlsx" --output ember.xlsx

redis-cli -x set top15windsolar-2020 < top15windsolar.json
redis-cli get top15windsolar-2020 | jq .

