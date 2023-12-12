#!/bin/bash source-this-script

configUsageGitconfig()
{
    local prefix="${1:?}"; shift
    local specialWhere="${1:?}"; shift

    cat <<HELPTEXT
${prefix}: items consist of a NAME:VALUE pair. It sets the ${specialWhere} NAME to VALUE unless it already has that value.
HELPTEXT
}
configUsageSystemGitconfig()
{
    configUsageGitconfig systemgitconfig "system-wide option"
}
configUsageUserGitconfig()
{
    configUsageGitconfig usergitconfig "per-user option for the entire local system"
}

getQuotedGitconfigCommand()
{
    local gitconfigCommand="${1:?}"; shift
    local name="${1:?}"; shift
    [ $# -eq 0 ] \
	&& printf '%s %q' "$gitconfigCommand" "$name" \
	|| printf '%s %q %q' "$gitconfigCommand" "$name" "$@"
}

typeset -A addedSystemGitconfigEntries=()
typeset -A addedUserGitconfigEntries=()
hasGitconfig()
{
    local prefix="${1:?}"; shift
    local gitconfigCommand="${1:?}"; shift
    local gitconfigEntriesDictName="${1:?}"; shift
    local gitconfigRecord="${1:?}"; shift

    local -n gitconfigEntries=$gitconfigEntriesDictName
    [ "${gitconfigEntries["$gitconfigRecord"]}" ] && return 0

    local name="${gitconfigRecord%%:*}"
    local value="${gitconfigRecord#*:}"
    local quotedGitconfigGetCommand="$(getQuotedGitconfigCommand "$gitconfigCommand --get" "$name" "$value")"

    local decoratedCheckCommand="$(decorateCommand "$quotedGitconfigGetCommand" "${decoration["${prefix}:$gitconfigRecord"]}")"
    [ "$(eval "$decoratedCheckCommand" 2>/dev/null)" = "$value" ]
}
hasSystemGitconfig()
{
    hasGitconfig systemgitconfig 'git config --system' addedSystemGitconfigEntries "$@"
}
hasUserGitconfig()
{
    hasGitconfig usergitconfig 'git userlocalconfig' addedUserGitconfigEntries "$@"
}

addGitconfig()
{
    local gitconfigEntriesDictName="${1:?}"; shift
    local gitconfigRecord="${1:?}"; shift
    local -n gitconfigEntries=$gitconfigEntriesDictName
    gitconfigEntries["$gitconfigRecord"]=t
}
addSystemGitconfig()
{
    addGitconfig addedSystemGitconfigEntries "$@"
}
addUserGitconfig()
{
    addGitconfig addedUserGitconfigEntries "$@"
}

installGitconfig()
{
    local prefix="${1:?}"; shift
    local gitconfigCommand="${1:?}"; shift
    local gitconfigEntriesDictName="${1:?}"; shift

    local -n gitconfigEntries=$gitconfigEntriesDictName
    [ ${#gitconfigEntries[@]} -gt 0 ] || return
    local gitconfigRecord; for gitconfigRecord in "${!gitconfigEntries[@]}"
    do
	local name="${gitconfigRecord%%:*}"
	local value="${gitconfigRecord#*:}"
	local quotedGitconfigSetCommand="$(getQuotedGitconfigCommand "$gitconfigCommand" "$name" "$value")"

	submitInstallCommand \
	    "$quotedGitconfigSetCommand" \
	    "${decoration["${prefix}:$gitconfigRecord"]}"
    done
}
installSystemGitconfig()
{
    installGitconfig systemgitconfig "${SUDO}${SUDO:+ }git config --system" addedSystemGitconfigEntries "$@"
}
installUserGitconfig()
{
    installGitconfig usergitconfig 'git userlocalconfig' addedUserGitconfigEntries "$@"
}

typeRegistry+=([systemgitconfig:]=SystemGitconfig)
typeRegistry+=([usergitconfig:]=UserGitconfig)
typeInstallOrder+=([720]=SystemGitconfig)
typeInstallOrder+=([721]=UserGitconfig)
