#!/bin/bash

SUDO=sudo; [ $EUID -eq 0 ] && SUDO=''

# Create a persistent audit trail of Python package (un-)installs.
# Fortunately, pip allows per-command configuration of the global --log
# parameter; global logging would inundate the log during the update checks.

readonly PIP_INSTALLLOG_FILESPEC=/var/log/pip/pip-install.log
touch-p --sudo --no-create --no-update -- "$PIP_INSTALLLOG_FILESPEC"

# Log install and uninstall actions into the same log to easily see the order of
# actions.
$SUDO pip3 config set install.log "$PIP_INSTALLLOG_FILESPEC"
$SUDO pip3 config set uninstall.log "$PIP_INSTALLLOG_FILESPEC"
