#!/bin/bash
set -o errexit
set -o nounset

### Header

REL_HERE=$(dirname "${BASH_SOURCE}")
HERE=$(cd "${REL_HERE}"; pwd)  # Get an absolute path
source "${HERE}/constants.sh"

### Actual script
SCALR_PATH="/opt/scalr/current"
ID_FILE="${SCALR_PATH}/app/etc/id"
SYNC_SCRIPT="${SCALR_PATH}/app/tools/sync_shared_roles.php"

cp -p "${ID_FILE}" "${ID_FILE}.bak"
echo "${SCALR_SYNC_ID}" > "${ID_FILE}"
php "${SYNC_SCRIPT}"
mv "${ID_FILE}.bak" "${ID_FILE}"
