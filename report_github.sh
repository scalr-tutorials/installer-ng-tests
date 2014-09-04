#!/bin/bash
set -o nounset
set -o errexit

# Init!
REL_HERE=$(dirname "${BASH_SOURCE}")
HERE=$(cd "${REL_HERE}"; pwd)  # Get an absolute path
source "${HERE}/constants.sh"

report_github_ci_status () {
  # That's what we'll report
  local status=${1}

  if [ -z "${CI_GITHUB_TOKEN}" ]; then
    echo "No CI token. Aborting report for: ${status}"
    return 0
  fi

  # Now find out what the hash is, by asking the remote.
  # We can't get it locally, because Scalr may not be deployed at this point yet.
  local branch_ref=$(git ls-remote --heads --exit-code "${INSTALLER_REPOSITORY_URL}" "${INSTALLER_BRANCH}")
  local branch_sha=$(echo "${branch_ref}" | cut -c-40)  # A commit hash is 40 chars long
  local payload="{\"state\": \"${status}\", \"context\": \"${SCALR_FARM_ROLE_ALIAS}-${SCALR_FARM_ID}\"}"

  curl --fail \
    --header "Authorization: token ${CI_GITHUB_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "${payload}" \
    "https://api.github.com/repos/${INSTALLER_REPOSITORY_PATH}/statuses/${branch_sha}"
}

# Main! If this isn't defined, we'll crash, but that's fine.
report_github_ci_status ${1}
