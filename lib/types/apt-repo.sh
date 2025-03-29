#!/bin/bash source-this-script

readonly APT_SOURCES_DIR=/etc/apt/sources.list.d

configUsageAptRepo()
{
    cat <<HELPTEXT
apt-repo: items consist of a
    NAME:'DEB-LINE'
pair, where DEB-LINE will be installed in ${APT_SOURCES_DIR}/NAME.list
You can use %ARCH% to refer to the machine architecture${aptRepoArch:+ (}${aptRepoArch}${aptRepoArch:+)} and %CODENAME%
to refer to the current release's codename${aptRepoCodename:+ (}${aptRepoCodename}${aptRepoCodename:+)}.
You can also specify a fallback as %CODENAME(fallback)%; that one will be tried
if the codename is not available.
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
    local isFallback="$1"; shift
    debLine="${debLine//%ARCH%/$aptRepoArch}"
    debLine="${debLine//%CODENAME%/$aptRepoCodename}"
    if [ "$isFallback" ]; then
	if [[ "$debLine" =~ %CODENAME\(.*\)% ]]; then
	    debLine="${debLine//%CODENAME\(/}"
	    debLine="${debLine//\)%/}"
	else
	    return 1
	fi
    else
	debLine="${debLine//%CODENAME(*([^)]))%/$aptRepoCodename}"
    fi
    printf %s "$debLine"
}

typeset -A addedAptRepos=()
typeset -a expandedDebLines=()
hasAptRepo()
{
    local name="${1%%:*}"
    local debLine="${1#"${name}:"}"
    if [ -z "$name" -o -z "$debLine" ]; then
	printf >&2 'ERROR: Invalid apt-repo item: "apt-repo:%s"\n' "$1"
	exit 3
    fi

    [ "${addedAptRepos["$name"]}" ] && return 0	# This repo has already been selected for installation.

    expandedDebLines["$name"]="$(expandDebLine "$debLine")"
    apt-add-debline --check --name "$name" -- "${expandedDebLines["$name"]}"; local status=$?
    if [ $status -eq 4 ]; then
	# Try a fallback if the DEB-LINE does not point to an existing APT repository.
	local fallbackDebLine; fallbackDebLine="$(expandDebLine "$debLine" t)" || return 99
	apt-add-debline --check --name "$name" -- "$fallbackDebLine"; status=$?
	[ $status -eq 4 ] && return 99 # If the DEB-LINE does not point to an existing APT repository, the entire definition should be skipped, as we cannot ensure the correct installation.
	expandedDebLines["$name"]="$fallbackDebLine"
    fi
    return $status
}

addAptRepo()
{
    local aptKeyRecord="${1:?}"; shift
    local name="${aptKeyRecord%%:*}"
    local debLine="${aptKeyRecord#"${name}:"}"

    addedAptRepos["$name"]=${expandedDebLines["$name"]}
}

installAptRepo()
{
    [ ${#addedAptRepos[@]} -gt 0 ] || return
    local isSingleRepository; [ ${#addedAptRepos[@]} -eq 1 ] && isSingleRepository=t
    local name; for name in "${!addedAptRepos[@]}"
    do
	local quotedDebLine; printf -v quotedDebLine '%q' "${addedAptRepos["$name"]}"

	submitInstallCommand "apt-add-debline${isSingleRepository:+ --update} --name $name -- $quotedDebLine"
    done
    [ "$isSingleRepository" ] || submitInstallCommand "${SUDO}${SUDO:+ }apt${isBatch:+ --assume-yes} update"
}
