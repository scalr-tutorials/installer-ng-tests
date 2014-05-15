#!/bin/bash
set -o nounset

: ${INSTALLER_LOG_FILE:="/root/install.log"}
: ${WAITER_LOG_FILE:="/root/waiter.log"}
: ${INSTALL_FAILED_EVENT:="ScalrInstallFailed"}

: ${TEST_REPORT_LINES:="400"}

# Install pgrep

install_pgrep () {
  if [ -f /etc/debian_version ]; then
    apt-get install -y procps
  elif [ -f /etc/redhat-release ]; then
    OS=redhat
    yum -y install procps
  else
    echo "Unsupported OS!"
    exit 2
  fi
}
command -v pgrep 2>&1 > /dev/null || install_pgrep

# Are we done installing?
pgrep -lf "python install.py" && echo "Install in progress" && exit 0

# Did we get any errors?
report_error () {
  /usr/local/bin/szradm --fire-event=$INSTALL_FAILED_EVENT
  exit 1
}

grep -PB$TEST_REPORT_LINES 'ERROR|FATAL' $INSTALLER_LOG_FILE && report_error  # There should be no error in the install log

grep 'Done' $WAITER_LOG_FILE || report_error  # The install should be done

exit 0
