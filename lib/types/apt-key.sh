#!/bin/bash source-this-script

configUsageAptKey()
{
    : ${INSTALL_DIR:=~/install}
    cat <<HELPTEXT
apt-key: items consist of a
    [MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]KEY-GLOB:[URL]
triplet.
If ${INSTALL_DIR}/(SUBDIR|*)/(NAME|*)/KEY-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the APT key
from URL will be downloaded (and put into ${INSTALL_DIR}/*
if it exists).
If no URL is given and the key does not exist, the installation will fail.
HELPTEXT
}

hasAptKey()
{
    return 1	# We cannot easily check for the imported key without downloading it. This item is meant to be used as a preinstall item, triggered by the installation of the main package, anyway.
}

typeset -a addedAptKeyRecords=()
addAptKey()
{
    local aptKeyRecord="${1:?}"; shift
    addedAptKeyRecords+=("$aptKeyRecord")
}

installAptKey()
{
    [ ${#addedAptKeyRecords[@]} -gt 0 ] || return
    local aptKeyRecord; for aptKeyRecord in "${addedAptKeyRecords[@]}"
    do
	local maxAge keyNameAndGlob keyUrl
	IFS=: read -r maxAge keyNameAndGlob keyUrl <<<"$aptKeyRecord"
	local keyGlob="${keyNameAndGlob##*/}"
	local keyName="${keyNameAndGlob%"$keyGlob"}"
	if [ -z "$keyGlob" ]; then
	    printf >&2 'ERROR: Invalid apt-key item: "apt-key:%s"\n' "$aptKeyRecord"
	    exit 3
	fi
	keyName="${keyName%/}"

	# Note: No sudo here, as the downloading will happen as the current user
	# and only the installation itself will be done through sudo.
	toBeInstalledCommands+=("apt-key-download${keyName:+ --application-name "'"}${keyName}${keyName:+"'"} --expression '$keyGlob'${maxAge:+ --max-age }$maxAge --url '$keyUrl'")
    done
}

typeRegistry+=([apt-key:]=AptKey)
typeInstallOrder+=([8]=AptKey)
