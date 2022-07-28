#!/bin/bash

profileDirspec=~/snap/firefox/common/.mozilla/firefox
[ -d "$profileDirspec" ] || profileDirspec=~/.mozilla/firefox
if [ ! -d "$profileDirspec" ]; then
    echo >&2 'ERROR: Firefox profiles directory not found.'
    exit 3
fi
printf '%s\n' "$profileDirspec"
