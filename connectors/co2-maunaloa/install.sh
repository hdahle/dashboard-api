#!/bin/sh
# Installer for "co2-maunaloa.sh" and "ch4-maunaloa.sh"
# Add script to crontab if it doesn't already exist
# Crontab entries are monthly
# H. Dahle

PWD=`pwd`
NUM=1

for SCRIPT in "co2-maunaloa.sh" "ch4-maunaloa.sh"
do

  if [ -f "${PWD}/${SCRIPT}" ]; then
    echo "Shell script found"
  else
    echo "Not found: ${PWD}/${SCRIPT} - aborting"
    exit
  fi

  # create new Crontab entry
  # staggering jobs 1 minute apart :-) being nice to NOAA.gov
  NEWENTRY="0 ${NUM} 2 * * ${PWD}/${SCRIPT}"
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

  NUM=$(( $NUM + 1 ))

done

# clean up
if [ -f newcrontab ]; then
  echo "Cleaning up"
  rm newcrontab
fi

