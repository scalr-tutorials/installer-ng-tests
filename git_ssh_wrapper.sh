#!/bin/sh
OPTS="-o UserKnownHostsFile=/dev/null -o CheckHostIP=no -o StrictHostKeyChecking=no"
if [ -n "$GIT_SSH_KEY_PATH" ]; then
  OPTS="${OPTS} -i ${GIT_SSH_KEY_PATH}"
fi

ssh ${OPTS} "$@"
