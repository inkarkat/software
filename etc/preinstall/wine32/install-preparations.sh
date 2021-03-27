#!/bin/bash

[ $EUID -eq 0 ] || exec sudo --set-home "${BASH_SOURCE[0]}" "$@"
set -e

dpkg --add-architecture i386
apt update
