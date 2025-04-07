#!/bin/bash source-this-script

configUsageSpecialIcon()
{
    local prefix="${1:?}"; shift
    local specialWhere="${1:?}"; shift

    cat <<HELPTEXT
${prefix}: items consist of SOURCE-FILE [SOURCE-FILE ...]
where SOURCE-FILE is either relative to the ./etc/files directory tree, or an
absolute filespec. The resulting icon is added to ${specialWhere}.
HELPTEXT
}
configUsageSystemIcon()
{
    configUsageSpecialIcon icon "the system-wide icons"
}
configUsageUserIcon()
{
    configUsageSpecialIcon usericon "the user's icons"
}

typeset -A addedSystemIconFilespecs=()
typeset -A addedUserIconFilespecs=()
hasSpecialIcon()
{
    local prefix="${1:?}"; shift
    local specialIconInstallerCommand="${1:?}"; shift
    local iconFilespecsDictName="added${1:?}Filespecs"; shift
    eval "set -- ${1:?}"

    local icon; for icon
    do
	local iconFilespec; if ! iconFilespec="$(getAbsoluteOrFilesFilespec "$icon")"; then
	    printf >&2 'ERROR: Invalid %s item: "%s:%s" due to missing SOURCE-FILE: "%s".\n' "$prefix" "$prefix" "$*" "$icon"
	    exit 3
	fi
	local -n iconFilespecs=$iconFilespecsDictName
	[ "${iconFilespecs["$iconFilespec"]}" ] && continue
	local quotedIconFilespec; printf -v quotedIconFilespec '%q' "$iconFilespec"
	local checkCommand="$specialIconInstallerCommand --check $quotedIconFilespec"
	local decoratedCheckCommand="$(decorateCommand "$checkCommand" "${decoration["${prefix}:$iconFilespec"]}")"
	eval "$decoratedCheckCommand" || return 1
    done
    return 0

}
hasSystemIcon()
{
    hasSpecialIcon icon 'addIcon --system-wide' SystemIcon "$@"
}
hasUserIcon()
{
    hasSpecialIcon usericon addIcon UserIcon "$@"
}

addSpecialIcon()
{
    local typeName="${1:?}"; shift; local iconFilespecsDictName="added${typeName}Filespecs"
    eval "set -- ${1:?}"

    local icon; for icon
    do
	local iconFilespec; if ! iconFilespec="$(getAbsoluteOrFilesFilespec "$icon")"; then
	    printf >&2 'ASSERT: SOURCE-FILE suddenly missing: "%s".\n' "$icon"
	    exit 3
	fi
	preinstallHook "$typeName" "$iconFilespec"
	local -n iconFilespecs=$iconFilespecsDictName
	iconFilespecs["$iconFilespec"]=t
	postinstallHook "$typeName" "$iconFilespec"
    done
}
addSystemIcon()
{
    addSpecialIcon SystemIcon "$@"
}
addUserIcon()
{
    addSpecialIcon UserIcon "$@"
}

installSpecialIcon()
{
    local prefix="${1:?}"; shift
    local specialIconInstallerCommand="${1:?}"; shift
    local iconFilespecsDictName="added${1:?}Filespecs"; shift
    local -n iconFilespecs=$iconFilespecsDictName
    [ ${#iconFilespecs[@]} -gt 0 ] || return

    printf -v quotedIconFilespecs ' %q' "${!iconFilespecs[@]}"
    submitInstallCommand \
	"${specialIconInstallerCommand}${quotedIconFilespecs}" \
	"${decoration["${prefix}:$specialInstallRecord"]}"
}
installSystemIcon()
{
    installSpecialIcon icon 'addIcon --system-wide' SystemIcon "$@"
}
installUserIcon()
{
    installSpecialIcon usericon addIcon UserIcon "$@"
}

typeRegistry+=([icon:]=SystemIcon)
typeRegistry+=([usericon:]=UserIcon)
typeInstallOrder+=([871]=SystemIcon)
typeInstallOrder+=([872]=UserIcon)
