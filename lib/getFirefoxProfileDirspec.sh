#!/bin/bash

profileDirspec="$FIREFOX_PROFILES_DIRSPEC"
[ -d "$profileDirspec" ] || profileDirspec=~/.mozilla/firefox
[ -d "$profileDirspec" ] || profileDirspec=~/snap/firefox/common/.mozilla/firefox
if [ ! -d "$profileDirspec" ]; then
    echo >&2 'ERROR: Firefox profiles directory not found.'
    exit 3
fi
printf '%s\n' "$profileDirspec"
