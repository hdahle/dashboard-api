#!/bin/sh
# MUSTFIX: redis-cli probably not in path when running as cron job

REDISKEY=nve-lcoe-2021
redis-cli -x set ${REDISKEY} < nve-lcoe.json
redis-cli get ${REDISKEY}
