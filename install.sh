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

# We'll need to be able to use sudo, remove requiretty from the sudoers file
SUDOERS=/etc/sudoers
TMP_SUDOERS=$(mktemp)
chmod 0440 "$TMP_SUDOERS"
grep --invert-match requiretty "$SUDOERS" > "$TMP_SUDOERS"
mv -f "$TMP_SUDOERS" "$SUDOERS"

echo "Downloading install script: ${INSTALL_SCRIPT_URL}"
curl -sfSLO "${INSTALL_SCRIPT_URL}"
chmod +x -- "${WORK_DIR}/${INSTALL_SCRIPT}"

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

if [[ "$SCALR_DEPLOY_VERSION" = "4.5" ]] ; then
  echo "$SCALR_INTERNAL_IP" >> $ANSWERS_FILE
fi

echo "${SCALR_CONNECTION_POLICY}" >> $ANSWERS_FILE
echo "$NOTIFY_SUBSCRIBE" >> $ANSWERS_FILE
echo "$NOTIFY_EMAIL" >> $ANSWERS_FILE

# Prepare options
CONFIGURATION_FILE="/root/solo.$$.json"  # We don't want to reuse an existing one (match-version)
echo "CONFIGURATION_FILE=${CONFIGURATION_FILE}"

echo -n "${CONFIGURATION_FILE}" > "${LAST_CONFIG_FILE_POINTER}"

if [[ -n "$SCALR_DEPLOY_ADVANCED" ]] ; then
  CONFIGURE_OPTIONS="--advanced"
else
  CONFIGURE_OPTIONS=""
fi

if [[ -n "${SCALR_COOKBOOK_RELEASE}" ]]; then
  echo "Using Coobkook release: '${SCALR_COOKBOOK_RELEASE}'"
  INSTALL_OPTIONS="--release=\"${SCALR_COOKBOOK_RELEASE}\""
else
  INSTALL_OPTIONS=""
fi

# Stop Scalarizr update agent if present. Older agents may trigger a conflict on the
# package manager
service scalr-upd-client stop || true

# Export options for the install script
export CONFIGURATION_FILE
export CONFIGURE_OPTIONS
export INSTALL_OPTIONS

# Launch the installer in the background
# Note: PYTHONUNBUFFERED might seem a it unusual here, but there is a reason.
# There are several invocations of Python in the install script, and the first one *will* consume
# the entirety of stdin (even if it does not need it) unless we have this option.
{ PYTHONUNBUFFERED=1 sh "${WORK_DIR}/${INSTALL_SCRIPT}" & } < "${ANSWERS_FILE}" 2>&1 > "${DIST_LOG_FILE}"
installer_pid=$!
echo "Started installer with PID: $installer_pid"


# Start a side-process to log running processes to a file
echo > "${PROC_LOG_FILE}"  # Clean proc file
{ sh -c "while kill -0 $installer_pid > /dev/null 2>&1; do date && ps aux --forest && echo && echo && echo && sleep 2; done" & } 2>&1 > "${PROC_LOG_FILE}"

# Wait for the install to exit before we do
echo > "${WAITER_LOG_FILE}"  # Clean waiter file first
while kill -0 "$installer_pid" > /dev/null 2>&1; do
  echo "$(date): Install in progress" | tee $WAITER_LOG_FILE
  sleep 10
done

echo "$(date): Install complete" | tee $WAITER_LOG_FILE

szradm --fire-event=$INSTALL_DONE_EVENT

# Restart the update agent, if it is there
service scalr-upd-client start || true
