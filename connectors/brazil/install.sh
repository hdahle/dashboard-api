#!/bin/sh
# Installer for "fires-brazil.sh"
# Add script to crontab if it doesn't already exist
# The script should run daily
# H. Dahle

PWD=`pwd`
SCRIPT="fires-brazil.sh"

if [ -f "${PWD}/${SCRIPT}" ]; then
  echo "Shell script found"
else
  echo "Not found: ${PWD}/${SCRIPT} - aborting"
  exit
fi

# create new Crontab entry
NEWENTRY="0 8 * * * ${PWD}/${SCRIPT}"
echo "${NEWENTRY}"

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


