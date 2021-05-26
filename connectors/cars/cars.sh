#!/bin/sh

redis-cli -x set polestar < polestar.json 
redis-cli get polestar | jq

redis-cli -x set eindhoven < eindhoven-study.json
redis-cli get eindhoven | jq

redis-cli -x set transport-environment-2020 < transportenvironment.json
redis-cli get transport-environment-2020 | jq
