#!/bin/bash source-this-script

configUsageYumRepo()
{
    cat <<HELPTEXT
yum-repo: items consist of a
    NAME:URL
pair, where URL will be used to install the NAME package for the Yum repository.
You can use %MAJOR% to refer to the current release's major version${major:+ (}${major}${major:+)}.
Note: As this is only used for installing, it's recommended to use this with a
preinstall: prefix.
HELPTEXT
}

typeRegistry+=([yum-repo:]=YumRepo)
typeInstallOrder+=([82]=YumRepo)

if ! exists yum; then
    hasYumRepo() { return 98; }
    installYumRepo() { :; }
    return
fi

readonly major="$(source /etc/os-release 2>/dev/null; echo "${VERSION_ID%%.*}")"

expandYumUrl()
{
    local yumUrl="${1:?}"; shift
    yumUrl="${yumUrl//%MAJOR%/$major}"
    printf %s "$yumUrl"
}

typeset -A addedYumRepos=()
hasYumRepo()
{
    local name="${1%%:*}"
    local yumUrl="${1#"${name}:"}"
    if [ -z "$name" -o -z "$yumUrl" ]; then
	printf >&2 'ERROR: Invalid yum-repo item: "yum-repo:%s"\n' "$1"
	exit 3
    fi

    [ "${addedYumRepos["$name"]}" ] && return 0	# This repo has already been selected for installation.

    hasYum "$name"
}

addYumRepo()
{
    local yumKeyRecord="${1:?}"; shift
    local name="${yumKeyRecord%%:*}"
    local yumUrl="${yumKeyRecord#"${name}:"}"

    addedYumRepos["$name"]="$(expandYumUrl "$yumUrl")"
}

installYumRepo()
{
    [ ${#addedYumRepos[@]} -gt 0 ] || return

    local quotedYumUrls; printf -v quotedYumUrls ' %q' "${addedYumRepos[@]}"
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }yum install$quotedYumUrls")
}
