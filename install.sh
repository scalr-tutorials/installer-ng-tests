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

# First, install pip
curl -sfSLO https://bootstrap.pypa.io/get-pip.py
python get-pip.py

pkg="scalr-manage"
if [[ -n "$INSTALLER_RELEASE" ]]; then
  pkg="$pkg==$INSTALLER_RELEASE"
fi
echo "Installing $pkg"
pip install "$pkg"

# Prepare the answers file
echo -n > $ANSWERS_FILE

if [[ -n "$SCALR_DEPLOY_ADVANCED" ]]; then

  echo "$SCALR_DEPLOY_REPOSITORY" >> $ANSWERS_FILE
  echo "$SCALR_DEPLOY_REVISION" >> $ANSWERS_FILE
  echo "$SCALR_DEPLOY_VERSION" >> $ANSWERS_FILE

  if [[ ! "$SCALR_DEPLOY_REPOSITORY" =~ (https?|git)://.* ]]; then
    # Check whether the repository provided is using a SSH-dependent protocol.
    # If it is, then provide the SSH key
    echo "$SCALR_DEPLOY_SSH_KEY" >> $ANSWERS_FILE
  fi

fi

echo "${!SCALR_IP_VARIABLE_NAME}" >> $ANSWERS_FILE
if [[ -n "$SCALR_USE_CUSTOM_HOST" ]]; then
  echo "n" >> $ANSWERS_FILE
  eval "${SCALR_CUSTOM_HOST_SCRIPT}" >> $ANSWERS_FILE
else
  echo "y" >> $ANSWERS_FILE
fi

if [[ -z "$SCALR_DEPLOY_ADVANCED" ]] || [[ "$SCALR_DEPLOY_VERSION" != "5.0" ]] ; then
  echo "$SCALR_INTERNAL_IP" >> $ANSWERS_FILE
fi

echo "${SCALR_CONNECTION_POLICY}" >> $ANSWERS_FILE
echo "$NOTIFY_SUBSCRIBE" >> $ANSWERS_FILE
echo "$NOTIFY_EMAIL" >> $ANSWERS_FILE

# Prepare the CLI
COMMON_OPTS="--configuration=/root/solo.json"

if [[ -n "$SCALR_DEPLOY_ADVANCED" ]] ; then
  CONFIGURE_OPTS="--advanced"
else
  CONFIGURE_OPTS=""
fi

if [[ -n "${SCALR_COOKBOOK_RELEASE}" ]]; then
  echo "Using Coobkook release: '${SCALR_COOKBOOK_RELEASE}'"
  INSTALL_OPTS="--release=\"${SCALR_COOKBOOK_RELEASE}\""
else
  INSTALL_OPTS=""
fi

#TODO
#INSTALLER_OPTS="${INSTALLER_OPTS} --verbose"


# Stop Scalarizr update agent if present. Older agents may trigger a conflict on the
# package manager
service scalr-upd-client stop || true

# Launch installer
scalr-manage $COMMON_OPTS configure $CONFIGURE_OPTS < $ANSWERS_FILE > $INSTALLER_LOG_FILE

nohup bash -c "scalr-manage $COMMON_OPTS install $INSTALL_OPTS < $ANSWERS_FILE" >> $INSTALLER_LOG_FILE &
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

scalr-manage $COMMON_OPTS document >> $INSTALLER_LOG_FILE

echo "$(date): Install complete" >> $WAITER_LOG_FILE

szradm --fire-event=$INSTALL_DONE_EVENT

# Restart the update agent, if it is there
service scalr-upd-client start || true
