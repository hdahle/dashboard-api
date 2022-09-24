#!/bin/sh
#
# Installer for "ghg-norway.js"
# Add script to crontab if it doesn't already exist
#
# H. Dahle

PWD=`pwd`

# must use eval for tilde-expansion to work...dirty
# REDISKEY="emissions-norway" # hard-coded in script to 'ghg-norway'
TMPDIR=$(mktemp -d)
LOGDIR=`eval echo ~${USER}/log`
SCRIPT="ghg-norway2.js"
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

# make new crontab entry: RUN ONCE A MONTH
NEWENTRY="0 0 1 * * cd ${PWD} && ${NODE} ${SCRIPT} >> ${LOGFILE} 2>&1"
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

