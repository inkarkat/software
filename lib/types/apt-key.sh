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
Note: As there's no checking whether the key has already been installed, it is
recommended to be used with a preinstall: prefix, so it is only offered before
the actual package has been installed.
HELPTEXT
}

typeRegistry+=([apt-key:]=AptKey)
typeInstallOrder+=([21]=AptKey)

if ! exists apt-key; then
    hasAptKey() { return 98; }
    installAptKey() { :; }
    return
fi

typeset -A addedAptKeyRecords=()
hasAptKey()
{
    [ "${addedAptKeyRecords["${1:?}"]}" ] && return 0	# This key has already been selected for installation.

    return 1	# We cannot easily check for the imported key without downloading it. This item is meant to be used as a preinstall item, triggered by the installation of the main package, anyway.
}

addAptKey()
{
    local aptKeyRecord="${1:?}"; shift
    addedAptKeyRecords["$aptKeyRecord"]=t
}

installAptKey()
{
    [ ${#addedAptKeyRecords[@]} -gt 0 ] || return
    local aptKeyRecord; for aptKeyRecord in "${!addedAptKeyRecords[@]}"
    do
	local maxAge keyNameAndGlob keyUrl
	IFS=: read -r maxAge keyNameAndGlob keyUrl <<<"$aptKeyRecord"
	local keyGlob="${keyNameAndGlob##*/}"
	local keyName="${keyNameAndGlob%"$keyGlob"}"
	if [ -z "$keyGlob" ]; then
	    printf >&2 'ERROR: Invalid apt-key item: "apt-key:%s"\n' "$aptKeyRecord"
	    exit 3
	fi
	local keyOutputNameArg=; isglob "$keyGlob" || printf -v keyOutputNameArg %q "$keyGlob"
	printf -v keyGlob %q "$keyGlob"
	keyName="${keyName%/}"
	printf -v keyUrl %q "$keyUrl"

	# Note: No sudo here, as the downloading will happen as the current user
	# and only the installation itself will be done through sudo.
	submitInstallCommand "apt-key-download${keyName:+ --application-name "'"}${keyName}${keyName:+"'"} --expression ${keyGlob}${maxAge:+ --max-age }$maxAge${keyUrl:+ --url }${keyUrl}${keyOutputNameArg:+ --output }${keyOutputNameArg}"
    done
}
