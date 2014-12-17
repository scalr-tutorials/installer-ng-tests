# Ensure that /usr/local/bin is on our path

export PATH=/usr/local/bin:$PATH

# Configurable constants

: ${INSTALL_SCRIPT_URL:="https://raw.githubusercontent.com/Scalr/installer-ng/master/dist/install.sh"}
INSTALL_SCRIPT="$(basename "${INSTALL_SCRIPT_URL}")"

: ${CI_GITHUB_TOKEN:=""}

: ${SCALR_SYNC_ID:="scalrqa"}

: ${SCALR_CONNECTION_POLICY:="auto"}

: ${SCALR_DEPLOY_ADVANCED:=""}    # Whether to enable the --advanced flag
: ${SCALR_COOKBOOK_RELEASE:=""}  # The cookbook release to use (--release flag)

: ${SCALR_DEPLOY_REPOSITORY:=""}  # Which repository to deploy from (full url for git)
: ${SCALR_DEPLOY_REVISION:=""}    # Which revision to deploy (e.g. HEAD)
: ${SCALR_DEPLOY_VERSION:=""}     # Which version is being deployed (e.g. 5.0)

: ${SCALR_DEPLOY_SSH_KEY:=""}     # A SSH key to use for git deployment. Only used if the repo is non-default and not a http / git repo


: ${SCALR_IP_VARIABLE_NAME:="SCALR_EXTERNAL_IP"}  # The variable to look up for the host IP
: ${SCALR_USE_CUSTOM_HOST:=""}                    # Whether to use a custom host
: ${SCALR_CUSTOM_HOST_SCRIPT:="hostname"}         # When using a custom host, the variable to look it up in

: ${NOTIFY_SUBSCRIBE:="n"}
: ${NOTIFY_EMAIL:="thomas@scalr.com"}

: ${ANSWERS_FILE:="/root/answers"}

: ${DIST_LOG_FILE:="/root/install.log"}
: ${INSTALLER_LOG_FILE:="/var/log/scalr-install.log"}
: ${WAITER_LOG_FILE:="/root/waiter.log"}

: ${INSTALL_DONE_EVENT:="ScalrInstallDone"}
: ${INSTALL_FAILED_EVENT:="ScalrInstallFailed"}
: ${START_TESTS_EVENT:="ScalrStartTest"}

INSTALLER_REPOSITORY_PATH="scalr/installer-ng"
INSTALLER_REPOSITORY_URL="git://github.com/${INSTALLER_REPOSITORY_PATH}.git"
