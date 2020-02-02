#!/bin/sh
#
# Installer for "co2-maunaloa.sh" and "ch4-maunaloa.sh"
# Add script to crontab if it doesn't already exist
# Run these scrips weekly. Data is updated by NOAA monthly, time of month varies
#
# H. Dahle

PWD=`pwd`
NUM=1

# must use eval for tilde-expansion to work...dirty
LOGDIR=`eval echo ~${USER}/log`

for SCRIPT in "co2-maunaloa.sh" "ch4-maunaloa.sh"
do

  LOGFILE="${LOGDIR}/${SCRIPT}.log"
  REDIS=`which redis-cli`

  echo "Using Redis at ${REDIS}"
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
    echo "Using logfile: ${LOGFILE}"
  fi
  
  # make sure script exists
  if [ -f "${PWD}/${SCRIPT}" ]; then
    echo "Shell script found"
  else
    echo "Not found: ${PWD}/${SCRIPT} - aborting"
    exit
  fi

  # create new Crontab entry
  # staggering jobs 1 hour apart :-) being nice to NOAA.gov
  NEWENTRY="0 ${NUM} * * 3 ${PWD}/${SCRIPT} ${REDIS} >> ${LOGFILE} 2>&1"
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

  NUM=$(( $NUM + 1 ))

done

# clean up
if [ -f newcrontab ]; then
  echo "Cleaning up"
  rm newcrontab
fi

