#!/bin/bash source-this-script

configUsagePip3Url()
{
    cat <<HELPTEXT
pip3+url: items consist of a
    NAME:URL
pair, where URL will be used to install the NAME package.
HELPTEXT
}

typeset -A addedPip3Urls=()
hasPip3Url()
{
    local packageName="${1%%:*}"
    local pip3Url="${1#"${packageName}:"}"
    if [ -z "$packageName" -o -z "$pip3Url" ]; then
	printf >&2 'ERROR: Invalid pip3+url item: "pip3+url:%s"\n' "$1"
	exit 3
    fi

    [ "${addedPip3Urls["$packageName"]}" ] && return 0	# This repo has already been selected for installation.

    hasPip3 "$packageName"
}

addPip3Url()
{
    local pip3KeyRecord="${1:?}"; shift
    local pip3PackageName="${pip3KeyRecord%%:*}"
    local pip3Url="${pip3KeyRecord#"${pip3PackageName}:"}"

    isAvailableOrUserAcceptsNative pip3 python3-pip 'pip3 Python 3 package manager' || return $?

    preinstallHook "$pip3PackageName"
    addedPip3Urls["$pip3PackageName"]="$pip3Url"
    externallyAddedPip3Packages["$pip3PackageName"]=t
    postinstallHook "$pip3PackageName"
}

installPip3Url()
{
    [ ${#addedPip3Urls[@]} -gt 0 ] || return

    local quotedPip3Urls; printf -v quotedPip3Urls ' %q' "${addedPip3Urls[@]}"
    submitInstallCommand "${SUDO}${SUDO:+ }pip3${isBatch:+ --yes} install$quotedPip3Urls"
}

typeRegistry+=([pip3+url:]=Pip3Url)
typeInstallOrder+=([301]=Pip3Url)
