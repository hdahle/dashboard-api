#!/bin/sh
#
# Installer for "co2-daily.js"
# Add script to crontab if it doesn't already exist
#
# H. Dahle

PWD=`pwd`

# must use eval for tilde-expansion to work...dirty
REDISKEY="co2-daily"
TMPDIR=$(mktemp -d)
LOGDIR=`eval echo ~${USER}/log`
SCRIPT="co2-daily.js"
LOGFILE="${LOGDIR}/cron.log"
NEWCRONTAB="${TMPDIR}/crontab"
CSVFILE="${LOGDIR}/${REDISKEY}.csv"
REDIS=`which redis-cli`
NODE=`which node`
echo "Using Redis at ${REDIS}"
echo "Using Node at ${NODE}"
echo "Logs are in ${LOGDIR}"
echo "CSVfile in ${CSVFILE}"

FTP="ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_trend_gl.txt"

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

# make new crontab entry: twice daily
NEWENTRY="15 2,14 * * * cd ${PWD} && curl ${FTP} > ${CSVFILE} && ${NODE} ${SCRIPT} --key ${REDISKEY} --file ${CSVFILE} >> ${LOGFILE} 2>&1"
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

echo "Adding new entry to crontab"
echo "${NEWENTRY}" >> ${NEWCRONTAB}
crontab ${NEWCRONTAB}



