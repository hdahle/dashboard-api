#!/bin/sh
#
# Installer for "schiphol.js"
# Add script to crontab if it doesn't already exist
#
# H. Dahle

PWD=`pwd`

# must use eval for tilde-expansion to work...dirty
REDISKEY="schiphol-flights"
TMPDIR=$(mktemp -d)
LOGDIR=`eval echo ~${USER}/log`
SCRIPT="schiphol.js"
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

# make new crontab entry: once daily at 3am UTC which is 1am norway DST
# when schiphol.js is run without --date it wil use yesterdays date which is what we want
NEWENTRY="18 3 * * * cd ${PWD} && ${NODE} ${SCRIPT} --appID `cat app.id` --appKey `cat app.key` --key ${REDISKEY}-${YEAR} >> ${LOGFILE} 2>&1"
echo "Crontab entry will be: ${NEWENTRY}"

# test if new entry already exists
crontab -l > ${NEWCRONTAB}
EXISTENTRY=`grep -F "${NEWENTRY}" < ${NEWCRONTAB}`

# add to crontab
if [ "${EXISTENTRY}" = "${NEWENTRY}"  ]; then
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
echo "${NEWENTRY}" >> ${NEWCRONTAB}
crontab ${NEWCRONTAB}



