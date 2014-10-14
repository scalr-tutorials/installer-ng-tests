: ${INSTALLER_LOG_FILE:="/root/install.log"}
: ${WAITER_LOG_FILE:="/root/waiter.log"}

: ${INSTALLER_BRANCH:="master"}

: ${CI_GITHUB_TOKEN:=""}

: ${SCALR_CONNECTION_POLICY:="auto"}

: ${SCALR_DEPLOY_ADVANCED:=""}

: ${SCALR_DEPLOY_REVISION:=""}
: ${SCALR_DEPLOY_REPOSITORY:=""}
: ${SCALR_DEPLOY_VERSION:=""}
: ${SCALR_DEPLOY_SSH_KEY:=""}

: ${SCALR_COOKBOOK_RELEASE:=""}

: ${NOTIFY_SUBSCRIBE:="n"}
: ${NOTIFY_EMAIL:="thomas@scalr.com"}

: ${ANSWERS_FILE:="/root/answers"}

: ${INSTALLER_LOG_FILE:="/root/install.log"}
: ${WAITER_LOG_FILE:="/root/waiter.log"}

: ${INSTALL_DONE_EVENT:="ScalrInstallDone"}
: ${INSTALL_FAILED_EVENT:="ScalrInstallFailed"}
: ${START_TESTS_EVENT:="ScalrStartTest"}

INSTALLER_REPOSITORY_PATH="scalr/installer-ng"
INSTALLER_REPOSITORY_URL="git://github.com/${INSTALLER_REPOSITORY_PATH}.git"
