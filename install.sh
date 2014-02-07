#!/bin/bash
set -o nounset
set -o errexit

: ${INSTALLER_BRANCH:="master"}
: ${ANSWERS_FILE:="/root/answers"}
: ${INSTALLER_LOG_FILE:="/root/install.log"}
: ${WAITER_LOG_FILE:="/root/waiter.log"}
: ${INSTALL_DONE_EVENT:="ScalrInstallDone"}

echo -n > $ANSWERS_FILE
echo "%external_ip%" >> $ANSWERS_FILE
echo "%internal_ip%" >> $ANSWERS_FILE
echo "auto" >> $ANSWERS_FILE

echo "Deploying Scalr from installer branch: $INSTALLER_BRANCH"
curl -O https://raw.github.com/Scalr/installer-ng/$INSTALLER_BRANCH/scripts/install.py

nohup bash -c "python install.py < $ANSWERS_FILE" > $INSTALLER_LOG_FILE &
installer_pid=$!
echo "Started installer with PID: $installer_pid"

nohup bash -c "while kill -0 $installer_pid > /dev/null 2>&1; do echo \"\$(date): Install in progress\" && sleep 10; done && echo \"\$(date): Install complete\" && /usr/local/bin/szradm --fire-event=$INSTALL_DONE_EVENT" > $WAITER_LOG_FILE &
waiter_pid=$!
echo "Started waiter with PID: $waiter_pid"
