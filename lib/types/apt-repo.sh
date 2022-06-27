#!/bin/bash source-this-script

readonly APT_SOURCES_DIR=/etc/apt/sources.list.d

configUsageAptRepo()
{
    cat <<HELPTEXT
apt-repo: items consist of a
    NAME:'DEB-LINE'
pair, where DEB-LINE will be installed in ${APT_SOURCES_DIR}/NAME.list
You can use %ARCH% to refer to the machine architecture${aptRepoArch:+ (}${aptRepoArch}${aptRepoArch:+)} and %CODENAME%
to refer to the current release's aptRepoCodename${aptRepoCodename:+ (}${aptRepoCodename}${aptRepoCodename:+)}.
Note: As this is only used for installing, it's recommended to use this with a
preinstall: prefix.
HELPTEXT
}

typeRegistry+=([apt-repo:]=AptRepo)
typeInstallOrder+=([81]=AptRepo)

if ! exists apt; then
    hasAptRepo() { return 98; }
    installAptRepo() { :; }
    return
fi

readonly aptRepoArch="$(dpkg --print-architecture)"
readonly aptRepoCodename="$(lsb_release --short --codename)"

expandDebLine()
{
    local debLine="${1:?}"; shift
    debLine="${debLine//%ARCH%/$aptRepoArch}"
    debLine="${debLine//%CODENAME%/$aptRepoCodename}"
    printf %s "$debLine"
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

    apt-add-debline --check --name "$name" -- "$(expandDebLine "$debLine")"; local status=$?
    [ $status -eq 4 ] && return 99 # If the DEB-LINE does not point to an existing APT repository, the entire definition should be skipped, as we cannot ensure the correct installation.
    return $status
}

addAptRepo()
{
    local aptKeyRecord="${1:?}"; shift
    local name="${aptKeyRecord%%:*}"
    local debLine="${aptKeyRecord#"${name}:"}"

    addedAptRepos["$name"]="$(expandDebLine "$debLine")"
}

installAptRepo()
{
    [ ${#addedAptRepos[@]} -gt 0 ] || return
    local name; for name in "${!addedAptRepos[@]}"
    do
	local quotedDebLine; printf -v quotedDebLine '%q' "${addedAptRepos["$name"]}"

	submitInstallCommand "apt-add-debline --name $name -- $quotedDebLine"
    done
    submitInstallCommand "${SUDO}${SUDO:+ }apt${isBatch:+ --assume-yes} update"
}
