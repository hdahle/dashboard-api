#!/bin/sh
#
# Installer for "csiro-alt.sh"
# Add script to crontab if it doesn't already exist
# Run this script twice a month. Data is updated by CSIRO monthly, time of month uncertain
#
# H. Dahle

PWD=`pwd`

# must use eval for tilde-expansion to work...dirty
LOGDIR=`eval echo ~${USER}/log`
LOGFILE="${LOGDIR}/cron.log"
TMPDIR=$(mktemp -d)
NEWCRONTAB="${TMPDIR}/newcrontab.txt"

REDIS=`which redis-cli`
echo "Using tmp directory ${TMPDIR}"
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

for SCRIPT in "csiro-alt.sh" "csiro-alt-yearly.sh" ; do

  # make sure script exists
  if [ -f "${PWD}/${SCRIPT}" ]; then
    echo "Shell script found: ${PWD}/${SCRIPT}"
  else
    echo "Not found: ${PWD}/${SCRIPT} - aborting"
    exit
  fi

  # make new crontab entry, once a month, on the 21st
  NEWENTRY="0 0 21 * * ${PWD}/${SCRIPT} ${REDIS} >> ${LOGFILE} 2>&1"
  echo "Creating crontab entry: ${NEWENTRY}"

  # test if new entry already exists
  crontab -l > ${NEWCRONTAB}
  EXISTENTRY=`grep -F "${NEWENTRY}" < ${NEWCRONTAB}`

  # add to crontab
  if [ "${EXISTENTRY}" = "${NEWENTRY}" ]; then
    echo "Already in crontab"
  else
    echo "Adding new entry to crontab"
    echo "${NEWENTRY}" >> ${NEWCRONTAB}
    crontab ${NEWCRONTAB}
  fi

done


