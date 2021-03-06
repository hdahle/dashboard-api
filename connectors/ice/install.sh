#!/bin/sh
#
# Installer for "ice-nsidc.sh"
# Add script to crontab if it doesn't already exist
# Run this scripts twice a month. Data is updated by NSIDC monthly, time of month uncertain
#
# H. Dahle

PWD=`pwd`

# must use eval for tilde-expansion to work...dirty
LOGDIR=`eval echo ~${USER}/log`
SCRIPT="ice-nsidc.sh"
LOGFILE="${LOGDIR}/cron.log"
REDIS=`which redis-cli`
echo "Using Redis at ${REDIS}"
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
  echo "Shell script found"
else
  echo "Not found: ${PWD}/${SCRIPT} - aborting"
  exit
fi

# make new crontab entry, twice a month, on 9th and 19th
NEWENTRY="0 0 9,19 * * ${PWD}/${SCRIPT} ${REDIS} >> ${LOGFILE} 2>&1"
echo "Creating crontab entry: ${NEWENTRY}"

# test if new entry already exists
crontab -l > newcrontab
EXISTENTRY=`grep -F "${NEWENTRY}" < newcrontab`

# add to crontab
if [ "${EXISTENTRY}" = "${NEWENTRY}"  ]; then
  echo "Already in crontab"
else
  echo "Adding new entry to crontab"
  echo "${NEWENTRY}" >> newcrontab
  crontab newcrontab
fi

# clean up
if [ -f newcrontab ]; then
  echo "Cleaning up"
  rm newcrontab
fi

