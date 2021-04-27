#!/bin/bash
set -e

readonly scriptDir="$([ "${BASH_SOURCE[0]}" ] && dirname -- "${BASH_SOURCE[0]}" || exit 3)"
[ -d "$scriptDir" ] || { echo >&2 "ERROR: Cannot determine script directory!"; exit 3; }

readonly APT_SOURCES="${1:?}"

"${scriptDir}/../../../../lib/withUnixhome" writeOrigOrBackup "$APT_SOURCES"
sed -i -e 's/^[[:space:]]*#[[:space:]]*deb-src/deb-src/' -- "$APT_SOURCES"
apt update
