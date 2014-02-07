#!/bin/bash
set -o nounset

: ${INSTALLER_LOG_FILE:="/root/install.log"}

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
grep -PB50 'ERROR|FATAL' $INSTALLER_LOG_FILE && exit 1

exit 0
