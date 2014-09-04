#!/bin/bash
set -o nounset
set -o errexit

REL_HERE=$(dirname "${BASH_SOURCE}")
HERE=$(cd "${REL_HERE}"; pwd)  # Get an absolute path
source "${HERE}/constants.sh"


# Notify GitHub that we're getting started here
"${HERE}/report_github.sh" "pending"

# Setup a working directory for this test
: ${WORK_DIR:="/tmp/scalr-install-$$"}

mkdir -p $WORK_DIR
cd $WORK_DIR
echo "Installing in: '$(pwd)'"

echo -n > $ANSWERS_FILE

if [ -n "$SCALR_DEPLOY_ADVANCED" ] ; then
  echo "$SCALR_DEPLOY_REVISION" >> $ANSWERS_FILE
  echo "$SCALR_DEPLOY_REPOSITORY" >> $ANSWERS_FILE
  echo "$SCALR_DEPLOY_VERSION" >> $ANSWERS_FILE
  echo "$SCALR_DEPLOY_SSH_KEY" >> $ANSWERS_FILE
  INSTALLER_OPTS="--advanced"
else
  INSTALLER_OPTS=""
fi

if [ -n "${SCALR_COOKBOOK_RELEASE}" ]; then
  echo "Using Coobkook release: '${SCALR_COOKBOOK_RELEASE}'"
  INSTALLER_OPTS="${INSTALLER_OPTS} --release=\"${SCALR_COOKBOOK_RELEASE}\""
fi

INSTALLER_OPTS="${INSTALLER_OPTS} --verbose"

echo "$SCALR_EXTERNAL_IP" >> $ANSWERS_FILE

if [ -z "$SCALR_DEPLOY_ADVANCED" ] || [ "$SCALR_DEPLOY_VERSION" != "5.0" ] ; then
  echo "$SCALR_INTERNAL_IP" >> $ANSWERS_FILE
fi

echo "auto" >> $ANSWERS_FILE
echo "$NOTIFY_SUBSCRIBE" >> $ANSWERS_FILE
echo "$NOTIFY_EMAIL" >> $ANSWERS_FILE


# Stop Scalarizr update agent if present. Older agents may trigger a conflict on the
# package manager
service scalr-upd-client stop || true

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

echo > $WAITER_LOG_FILE  # Clean waiter file first

while kill -0 $installer_pid > /dev/null 2>&1; do
  echo "$(date): Install in progress" >> $WAITER_LOG_FILE
  sleep 10
done

echo "$(date): Install complete" >> $WAITER_LOG_FILE

szradm --fire-event=$INSTALL_DONE_EVENT

# Restart the update agent, if it is there
service scalr-upd-client start || true
