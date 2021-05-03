#!/bin/sh
# Installer for "bitcoin-power.sh" and "bitcoin-price.js"
# Add script to crontab if it doesn't already exist
# The script should run daily
# H. Dahle

PWD=`pwd`
SCRIPT="bitcoin-power.sh"
SCRIPTJS="bitcoin-price.js"
REDISKEYJS="bitcoin-price"

# must use eval for tilde-expansion to work...dirty
LOGDIR=`eval echo ~${USER}/log`
LOGFILE="${LOGDIR}/${SCRIPT}.log"
REDIS=`which redis-cli`
NODE=`which node`

echo "Using Redis at ${REDIS}"
echo "Using Node at ${NODE}"
echo "Logs are in ${LOGDIR}"

# Check if log directory exists
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
  echo "Using existing logfile: ${LOGFILE}"
fi

# check if script-file exists
if [ -f "${PWD}/${SCRIPT}" ]; then
  echo "Shell script found"
else
  echo "Not found: ${PWD}/${SCRIPT} - aborting"
  exit
fi

# check if script-file exists
if [ -f "${PWD}/${SCRIPTJS}" ]; then
  echo "Shell script found"
else
  echo "Not found: ${PWD}/${SCRIPTJS} - aborting"
  exit
fi

# create new Crontab entry
NEWENTRY="0 10 * * * ${PWD}/${SCRIPT} ${REDIS} >> ${LOGFILE} 2>&1"
echo "Creating crontab-entry: ${NEWENTRY}"
# test if new entry already exists
crontab -l > newcrontab
EXISTENTRY=`grep -F "${NEWENTRY}" < newcrontab`
# add to crontab
if [ "${EXISTENTRY}" = "${NEWENTRY}"  ]; then
  echo "Already in crontab: ${NEWENTRY}"
else
  echo "Adding new entry to crontab"
  echo "${NEWENTRY}" >> newcrontab
  crontab newcrontab
fi


# create new Crontab entry
NEWENTRY="0 11 * * * ${NODE} ${PWD}/${SCRIPTJS} --key ${REDISKEYJS} >> ${LOGFILE} 2>&1"
echo "Creating crontab-entry: ${NEWENTRY}"
# test if new entry already exists
crontab -l > newcrontab
EXISTENTRY=`grep -F "${NEWENTRY}" < newcrontab`
# add to crontab
if [ "${EXISTENTRY}" = "${NEWENTRY}"  ]; then
  echo "Already in crontab: ${NEWENTRY}"
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


