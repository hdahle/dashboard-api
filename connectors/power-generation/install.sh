#!/bin/sh
#
# Installer for "spain-electricity.js"
# Add script to crontab if it doesn't already exist
#
# H. Dahle

PWD=`pwd`

# node spain-electricity.js --year 2020 --key spain-electricity-2020

# must use eval for tilde-expansion to work...dirty
REDISKEY="spain-electricity"
TMPDIR=$(mktemp -d)
LOGDIR=`eval echo ~${USER}/log`
SCRIPT="spain-electricity.js"
LOGFILE="${LOGDIR}/cron.log"
NEWCRONTAB="${TMPDIR}/crontab"
NODE=`which node`
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

# make new crontab entry: run at 2am and 3am GMT, sometimes remote server fails...
NEWENTRY="0 2,3 * * * cd ${PWD} && ${NODE} ${SCRIPT} --key ${REDISKEY}-${YEAR} --year ${YEAR} >> ${LOGFILE} 2>&1"
echo "Crontab entry will be: ${NEWENTRY}"

# test if new entry already exists
crontab -l > ${NEWCRONTAB}
EXISTENTRY1=`grep -F "${NEWENTRY}" < ${NEWCRONTAB}`

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



