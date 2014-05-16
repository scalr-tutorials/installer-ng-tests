#!/bin/bash
set -o nounset
set -o errexit

: ${WORK_DIR:="/tmp/scalr-install-$$"}

: ${INSTALLER_BRANCH:="master"}

: ${SCALR_DEPLOY_ADVANCED:=""}

: ${SCALR_DEPLOY_REVISION:=""}
: ${SCALR_DEPLOY_REPOSITORY:=""}
: ${SCALR_DEPLOY_RELEASE:=""}
: ${SCALR_DEPLOY_SSH_KEY:=""}

: ${NOTIFY_SUBSCRIBE:="n"}
: ${NOTIFY_EMAIL:="thomas@scalr.com"}

: ${ANSWERS_FILE:="/root/answers"}

: ${INSTALLER_LOG_FILE:="/root/install.log"}
: ${WAITER_LOG_FILE:="/root/waiter.log"}
: ${INSTALL_DONE_EVENT:="ScalrInstallDone"}

# Find szradm

szradm=$(PATH=/usr/local/bin:/usr/bin which szradm)

mkdir -p $WORK_DIR
cd $WORK_DIR
echo "Installing in: '$(pwd)'"

echo -n > $ANSWERS_FILE

if [ -n "$SCALR_DEPLOY_ADVANCED" ] ; then
  echo "$SCALR_DEPLOY_REVISION" >> $ANSWERS_FILE
  echo "$SCALR_DEPLOY_REPOSITORY" >> $ANSWERS_FILE
  echo "$SCALR_DEPLOY_RELEASE" >> $ANSWERS_FILE
  echo "$SCALR_DEPLOY_SSH_KEY" >> $ANSWERS_FILE
  INSTALLER_OPTS="--advanced"
else
  INSTALLER_OPTS=""
fi


echo "$SCALR_EXTERNAL_IP" >> $ANSWERS_FILE

if [ -z "$SCALR_DEPLOY_ADVANCED" ] || [ "$SCALR_DEPLOY_RELEASE" != "ee" ] ; then
  echo "$SCALR_INTERNAL_IP" >> $ANSWERS_FILE
fi

echo "auto" >> $ANSWERS_FILE
echo "$NOTIFY_SUBSCRIBE" >> $ANSWERS_FILE
echo "$NOTIFY_EMAIL" >> $ANSWERS_FILE


# Retrieve installer and launch it

echo "Deploying Scalr from installer branch: $INSTALLER_BRANCH"
curl --location --remote-name --fail --sslv3 https://raw.github.com/Scalr/installer-ng/$INSTALLER_BRANCH/scripts/install.py

nohup bash -c "python install.py $INSTALLER_OPTS < $ANSWERS_FILE" > $INSTALLER_LOG_FILE &
installer_pid=$!
echo "Started installer with PID: $installer_pid"


# Start a side-process to log running processes to a file

: ${PROC_LOG_FILE:="/root/proc.log"}
nohup bash -c "while kill -0 $installer_pid > /dev/null 2>&1; do date && ps aux --forest && echo && echo && echo && sleep 2; done" > $PROC_LOG_FILE &


# Wait for the install to exit before we do
# If we exited before Chef is done, the Scalarizr update agent may attempt an upgrade while we install

while kill -0 $installer_pid; do
  echo "$(date): Install in progress" > $WAITER_LOG_FILE
  sleep 10
done

echo "$(date): Install complete" > $WAITER_LOG_FILE

$szradm --fire-event=$INSTALL_DONE_EVENT
