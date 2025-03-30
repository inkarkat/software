#!/bin/bash

profileDirspec="$THUNDERBIRD_PROFILES_DIRSPEC"
[ -d "$profileDirspec" ] || profileDirspec=~/snap/thunderbird/common/.thunderbird
[ -d "$profileDirspec" ] || profileDirspec=~/.thunderbird
if [ ! -d "$profileDirspec" ]; then
    echo >&2 'ERROR: Thunderbird profiles directory not found.'
    exit 3
fi
printf '%s\n' "$profileDirspec"
