#!/bin/bash

SUDO=sudo; [ $EUID -eq 0 ] && SUDO=''

# Suppress this warning:
# > WARNING: You are using pip version 21.0; however, version 21.0.1 is available.
# > You should consider upgrading via the '/usr/bin/python3 -m pip install --upgrade pip' command.
# As I install pip3 via the distribution's native package manager, it is in
# charge of pip3 updates (and usually is far more conservative than the pip3
# releases). If I had wanted to closely follow pip3 releases, I would have
# directly installed pip3, not through the package manager.
# Source:
#   https://stackoverflow.com/questions/46288847/how-to-suppress-pip-upgrade-warning

$SUDO pip3 config set global.disable-pip-version-check true
