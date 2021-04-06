#!/bin/bash source-this-script

configUsageYumUrl()
{
    cat <<HELPTEXT
yum+url: items consist of a
    NAME:URL
pair, where URL will be used to install the NAME package.
You can use %MAJOR% to refer to the current release's major version${major:+ (}${major}${major:+)}.
Note: If you use this for installing a Yum repository (like EPEL), it's
necessary to use this with a preinstall: prefix (also to have it executed before
the dependent yum package installation).
HELPTEXT
}

typeRegistry+=([yum+url:]=YumUrl)
typeInstallOrder+=([132]=YumUrl)

if ! exists yum; then
    hasYumUrl() { return 98; }
    installYumUrl() { :; }
    return
fi

readonly major="$(source /etc/os-release 2>/dev/null; echo "${VERSION_ID%%.*}")"

expandYumUrl()
{
    local yumUrl="${1:?}"; shift
    yumUrl="${yumUrl//%MAJOR%/$major}"
    printf %s "$yumUrl"
}

typeset -A addedYumUrls=()
hasYumUrl()
{
    local name="${1%%:*}"
    local yumUrl="${1#"${name}:"}"
    if [ -z "$name" -o -z "$yumUrl" ]; then
	printf >&2 'ERROR: Invalid yum+url item: "yum+url:%s"\n' "$1"
	exit 3
    fi

    [ "${addedYumUrls["$name"]}" ] && return 0	# This repo has already been selected for installation.

    hasYum "$name"
}

addYumUrl()
{
    local yumKeyRecord="${1:?}"; shift
    local name="${yumKeyRecord%%:*}"
    local yumUrl="${yumKeyRecord#"${name}:"}"

    addedYumUrls["$name"]="$(expandYumUrl "$yumUrl")"
}

installYumUrl()
{
    [ ${#addedYumUrls[@]} -gt 0 ] || return

    local quotedYumUrls; printf -v quotedYumUrls ' %q' "${addedYumUrls[@]}"
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }yum install$quotedYumUrls")
}
