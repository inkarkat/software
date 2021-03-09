#!/bin/bash source-this-script

readonly APT_SOURCES_DIR=/etc/apt/sources.list.d

configUsageAptRepo()
{
    cat <<HELPTEXT
apt-repo: items consist of a
    NAME:'DEB-LINE'
pair, where DEB-LINE will be installed in ${APT_SOURCES_DIR}/NAME.list
HELPTEXT
}

typeset -A addedAptRepos=()
hasAptRepo()
{
    local name="${1%%:*}"
    local debLine="${1#"${name}:"}"
    if [ -z "$name" -o -z "$debLine" ]; then
	printf >&2 'ERROR: Invalid apt-repo item: "apt-repo:%s"\n' "$1"
	exit 3
    fi

    [ "${addedAptRepos["$name"]}" ] && return 0	# This repo has already been selected for installation.

    local aptSourceFilespec="${APT_SOURCES_DIR}/${name}.list"
    [ -e "$aptSourceFilespec" ] || return 1
    grep --quiet --fixed-strings --line-regexp "$debLine" -- "$aptSourceFilespec"
}

addAptRepo()
{
    local aptKeyRecord="${1:?}"; shift
    local name="${aptKeyRecord%%:*}"
    local debLine="${aptKeyRecord#"${name}:"}"

    addedAptRepos["$name"]="$debLine"
}

installAptRepo()
{
    [ ${#addedAptRepos[@]} -gt 0 ] || return
    local name; for name in "${!addedAptRepos[@]}"
    do
	printf -v quotedDebLine '%q' "${addedAptRepos["$name"]}"

	toBeInstalledCommands+=("printf %s\\\\n $quotedDebLine|${SUDO}${SUDO:+ }tee ${APT_SOURCES_DIR}/${name}.list")
    done
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }apt update")
}

typeRegistry+=([apt-repo:]=AptRepo)
typeInstallOrder+=([9]=AptRepo)
