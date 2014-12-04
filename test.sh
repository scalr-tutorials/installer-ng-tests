#!/bin/bash
set -o errexit
set -o nounset

REL_HERE=$(dirname "${BASH_SOURCE}")
HERE=$(cd "${REL_HERE}"; pwd)  # Get an absolute path
source "${HERE}/constants.sh"

export GIT_SSH="${HERE}/git_ssh_wrapper.sh"
export GIT_SSH_KEY_BODY="${SCALR_DEPLOY_SSH_KEY}"

: ${TEST_REPORT_LINES:="400"}
: ${SCALR_START_TESTS:=""}

# Find szradm

szradm=$(PATH=/usr/local/bin:/usr/bin which szradm)

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
  curl --silent --location --fail "http://stedolan.github.io/jq/download/linux64/jq" > $jq_path
  chmod +x $jq_path
}
command -v jq 2>&1 > /dev/null || install_jq

# Are we done installing?
pgrep -lf "python install.py" && echo "Install in progress" && exit 0

report_error () {
  echo "TESTS FAILED!"
  "${HERE}/report_github.sh" "failure"
  $szradm --fire-event=$INSTALL_FAILED_EVENT
  exit 1
}

echo "Testing for errors"
grep -PB$TEST_REPORT_LINES 'ERROR|FATAL' $INSTALLER_LOG_FILE && report_error  # There should be no error in the install log


echo "Testing for proper install termination"
grep --silent 'Congratulations' $INSTALLER_LOG_FILE || {
  # If this wasn't there, there must be something wrong
  tail -n "$TEST_REPORT_LINES" "$INSTALLER_LOG_FILE"
  report_error  # The install should be done
}


echo "Testing for timezone consistency"
# Note: this may fail if we test at the second where we change hours... Probably not common enough to care: it's just a test script
mysql_hour=$(mysql --user=root --password=$(jq --raw-output ".mysql.server_root_password" "/root/solo.json") --skip-column-names --batch --execute="SELECT DATE_FORMAT(NOW(), '%H')")
php_hour=$(php -r 'echo date("H") . "\n";')

if [ "$mysql_hour" != "$php_hour" ]; then
  report_error
fi

echo "Testing that mysqlnd is not used"
php -m | grep "mysqlnd" && report_error

echo "Testing that Apache is running"
curl --silent --head --location --fail http://127.0.0.1/ || report_error

if [ -n $SCALR_START_TESTS ]; then
  $szradm --fire-event=$START_TESTS_EVENT
fi

echo "Checking services are running"
for service in msgsender dbqueue plotter poller szrupdater analytics_poller analytics_processor; do
  echo "Checking service: $service"
  service "$service" status || report_error
done

# Now, run user tests!
# TODO - Bypass if that key isn't defined

USER_CLIENT_REPO_NAME="scalr-user-client"
USER_CLIENT_REPO_URL="git@github.com:Scalr/${USER_CLIENT_REPO_NAME}.git"
USER_CLIENT_INSTALL_DIR=$(mktemp -d)  # No need for a trap here, we don't have errexit set

# Bootstrap Python environment (possibly all the way from distutils)
easy_install --upgrade pip || true
pip install --upgrade setuptools || true

cd "${USER_CLIENT_INSTALL_DIR}"
git clone "${USER_CLIENT_REPO_URL}" && cd "${USER_CLIENT_REPO_NAME}" && python setup.py install  # We should have setuptools at this point. If we don't that's an error!

cd "${HERE}"  # This is where the Python tests are
rm -r -- "${USER_CLIENT_INSTALL_DIR}"

python -c 'import scalr_client' || {
  echo "Failed to install the Scalr user client!"
  report_error
}

echo "Running Python user tests"
python user.py || report_error

"${HERE}/report_github.sh" "success"
exit 0
