#!/bin/bash
set -o nounset

: ${INSTALLER_LOG_FILE:="/root/install.log"}
: ${WAITER_LOG_FILE:="/root/waiter.log"}

: ${TEST_REPORT_LINES:="400"}

: ${SCALR_START_TESTS:=""}

: ${INSTALL_FAILED_EVENT:="ScalrInstallFailed"}
: ${START_TESTS_EVENT:="ScalrStartTest"}

# Find szradm

szradm=$(PATH=/usr/local/bin:/usr/bin which szradm)

# Ensure that /usr/local/bin is on our path
PATH=/usr/local/bin:$PATH

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

install_jq () {
  jq_path=/usr/local/bin/jq
  curl --location --fail "http://stedolan.github.io/jq/download/linux64/jq" > $jq_path
  chmod +x $jq_path
}
command -v jq 2>&1 > /dev/null || install_jq

# Are we done installing?
pgrep -lf "python install.py" && echo "Install in progress" && exit 0

# Did we get any errors?
report_error () {
  $szradm --fire-event=$INSTALL_FAILED_EVENT
  exit 1
}

echo "Testing for errors"
grep -PB$TEST_REPORT_LINES 'ERROR|FATAL' $INSTALLER_LOG_FILE && report_error  # There should be no error in the install log


echo "Testing for proper install termination"
grep 'Congratulations' $INSTALLER_LOG_FILE || report_error  # The install should be done


echo "Testing for timezone consistency"
# Note: this may fail if we test at the second where we change hours... Probably not common enough to care: it's just a test script
mysql_hour=$(mysql --user=root --password=$(jq /root/solo.json ".mysql.server_root_password") --skip-column-names --batch --execute="SELECT HOUR(NOW())")
php_hour=$(php -r 'echo date("H") . "\n";')

if [ "$mysql_hour" != "$php_hour" ]; then
  report_error
fi

if [ -n $SCALR_START_TESTS ]; then
  $szradm --fire-event=$START_TESTS_EVENT
fi

exit 0
