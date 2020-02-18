#!/bin/sh
#
# Installer for "uah-temperature.sh"
# Add script to crontab if it doesn't already exist
# Run this scripts twice a month. Data is updated by NOAA monthly, time of month uncertain
#
# H. Dahle

PWD=`pwd`

# must use eval for tilde-expansion to work...dirty
LOGDIR=`eval echo ~${USER}/log`
SCRIPT="uah-temperature.sh"
LOGFILE="${LOGDIR}/cron.log"
TMPDIR=$(mktmp -d)
NEWCRON="${TMPDIR}/crontab"
REDIS=`which redis-cli`
echo "Using Redis at ${REDIS}"
echo "Logs are in ${LOGDIR}"

# check if log directory exists
if [ ! -d "${LOGDIR}" ]; then
    echo -n "Creating ${LOGDIR} ... "
    mkdir ${LOGDIR} 
    if [ ! -d "${LOGDIR}" ]; then
      echo "unable to create ${LOGDIR} - aborting"
      exit
    else
      echo "done"
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

# make new crontab entry, once a month
NEWENTRY="0 0 7 * * ${PWD}/${SCRIPT} ${REDIS} >> ${LOGFILE} 2>&1"
echo -n "Creating crontab entry: ${NEWENTRY} ... "

# test if new entry already exists
crontab -l > ${NEWCRON}
EXISTENTRY=`grep -F "${NEWENTRY}" < ${NEWCRON}`

# add to crontab
if [ "${EXISTENTRY}" = "${NEWENTRY}" ]; then
  echo "Already in crontab"
else
  echo "Adding new entry to crontab"
  echo "${NEWENTRY}" >> ${NEWCRON}
  crontab ${NEWCRON}
fi

