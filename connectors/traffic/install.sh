#!/bin/sh
#
# Installer for "co2-daily.js"
# Add script to crontab if it doesn't already exist
#
# H. Dahle

PWD=`pwd`

# must use eval for tilde-expansion to work...dirty
REDISKEY="norway-traffic"
TMPDIR=$(mktemp -d)
LOGDIR=`eval echo ~${USER}/log`
SCRIPT="traffic.js"
LOGFILE="${LOGDIR}/cron.log"
NEWCRONTAB="${TMPDIR}/crontab"
REDIS=`which redis-cli`
NODE=`which node`
echo "Using Redis at ${REDIS}"
echo "Using Node at ${NODE}"
echo "Logs are in ${LOGDIR}"


# check if log directory exists
if [ ! -d "${LOGDIR}" ]; then
    echo "Creating ${LOGDIR}"
    mkdir ${LOGDIR} 
    if [ ! -d "${LOGDIR}" ]; then
      echo "Could not create ${LOGDIR} - aborting"
      exit
    else
      echo "Logdir created"
    fi
else
  echo "Using logfile: ${LOGFILE}"
fi

# make sure script exists
if [ -f "${PWD}/${SCRIPT}" ]; then
  echo "Shell script found: ${PWD}/${SCRIPT}"
else
  echo "Not found: ${PWD}/${SCRIPT} - aborting"
  exit
fi

YEAR=2020
BANEHEIA=57166V121303
SMESTAD=24764V625406

# make new crontab entry: once daily
NEWENTRY1="16 7 * * * cd ${PWD} && ${NODE} ${SCRIPT} --station ${SMESTAD} --key ${REDISKEY}-smestad-${YEAR} --year ${YEAR} >> ${LOGFILE} 2>&1"
echo "Crontab entry will be: ${NEWENTRY1}"
NEWENTRY2="17 7 * * * cd ${PWD} && ${NODE} ${SCRIPT} --station ${BANEHEIA} --key ${REDISKEY}-baneheia-${YEAR} --year ${YEAR} >> ${LOGFILE} 2>&1"
echo "Crontab entry will be: ${NEWENTRY2}"

# test if new entry already exists
crontab -l > ${NEWCRONTAB}
EXISTENTRY1=`grep -F "${NEWENTRY1}" < ${NEWCRONTAB}`
EXISTENTRY2=`grep -F "${NEWENTRY2}" < ${NEWCRONTAB}`

# add to crontab
if [ "${EXISTENTRY}" = "${NEWENTRY1}"  ]; then
  echo "Already in crontab"
  exit
fi
# add to crontab
if [ "${EXISTENTRY}" = "${NEWENTRY2}"  ]; then
  echo "Already in crontab"
  exit
fi

echo -n "Add to Crontab (y/n)? "
read ANSWER

if [ "${ANSWER}" != "${ANSWER#[Yy]}" ] ;then
    echo Yes
else
    echo No
    exit
fi

echo "Adding new entries to crontab"
echo "${NEWENTRY1}" >> ${NEWCRONTAB}
echo "${NEWENTRY2}" >> ${NEWCRONTAB}
crontab ${NEWCRONTAB}



