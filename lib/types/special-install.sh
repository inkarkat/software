#!/bin/bash source-this-script

configUsageSpecialInstall()
{
    local prefix="${1:?}"; shift
    local specialWhere="${1:?}"; shift

    cat <<HELPTEXT
${prefix}: items consist of createDesktopEntry arguments
    -e|--exec COMMAND|-c|--command COMMANDLINE [-n|--name NAME] [-i|--icon ICON] [-C|--comment COMMENT] [-t|--category CATEGORY [-t ...]] DESKTOP-ENTRY
or just
    SOURCE-FILE
SOURCE-FILE is either relative to the ./etc/files directory tree, or an absolute
filespec.
In both cases, the resulting DESKTOP-ENTRY is added to ${specialWhere}.
HELPTEXT
}
configUsageStartmenu()
{
    configUsageSpecialInstall startmenu "the system-wide start menu"
}
configUsageUserStartmenu()
{
    configUsageSpecialInstall userstartmenu "the user's start menu"
}
configUsageAutostart()
{
    configUsageSpecialInstall autostart "the user's startup applications"
}

typeset -A addedStartmenuEntries=()
typeset -A addedUserStartmenuEntries=()
typeset -A addedAutostartEntries=()
hasSpecialInstall()
{
    local prefix="${1:?}"; shift
    local specialInstallerCommand="${1:?}"; shift
    local specialInstallEntriesDictName="${1:?}"; shift
    local specialInstallRecord="${1:?}"; shift

    local -n specialInstallEntries=$specialInstallEntriesDictName
    [ "${specialInstallEntries["$specialInstallRecord"]}" ] && return 0

    # Always delegate the check to the addTo... commands with --check option
    # (which only test the target's existence and do not need a valid source
    # file); createDesktopEntry itself has no such check. These commands
    # encapsulate the destination locations, avoiding that we need to duplicate
    # them here one more.
    eval "set -- $specialInstallRecord"
    local specialName="${!#}"
    local checkCommand="$specialInstallerCommand --check ${specialName%.desktop}.desktop"
    local decoratedCheckCommand="$(decorateCommand "$checkCommand" "${decoration["${prefix}:$specialInstallRecord"]}")"
    eval "$decoratedCheckCommand"
}
hasStartmenu()
{
    hasSpecialInstall startmenu 'addToStartMenu --system-wide' addedStartmenuEntries "$@"
}
hasUserStartmenu()
{
    hasSpecialInstall userstartmenu addToStartMenu addedUserStartmenuEntries "$@"
}
hasAutostart()
{
    hasSpecialInstall autostart addToAutostart addedAutostartEntries "$@"
}

addSpecialInstall()
{
    local specialInstallEntriesDictName="${1:?}"; shift
    local specialInstallRecord="${1:?}"; shift

    eval "set -- $specialInstallRecord"
    local specialName="${!#}"

    preinstallHook "$specialName"
    local -n specialInstallEntries=$specialInstallEntriesDictName
    specialInstallEntries["$specialInstallRecord"]=t
    postinstallHook "$specialName"
}
addStartmenu()
{
    addSpecialInstall addedStartmenuEntries "$@"
}
addUserStartmenu()
{
    addSpecialInstall addedUserStartmenuEntries "$@"
}
addAutostart()
{
    addSpecialInstall addedAutostartEntries "$@"
}

installSpecialInstall()
{
    local prefix="${1:?}"; shift
    local specialCreatorCommand="${1:?}"; shift
    local specialInstallerCommand="${1:?}"; shift
    local specialInstallEntriesDictName="${1:?}"; shift
    local -n specialInstallEntries=$specialInstallEntriesDictName
    [ ${#specialInstallEntries[@]} -gt 0 ] || return
    local specialInstallRecord; for specialInstallRecord in "${!specialInstallEntries[@]}"
    do
	eval "set -- $specialInstallRecord"
	local specialSourceFilespec specialCommand="$specialCreatorCommand"
	if [ $# -eq 1 ] && specialSourceFilespec="$(getAbsoluteOrFilesFilespec "$1")"; then
	    # This is the SOURCE-FILE variant. Reassemble the
	    # specialInstallRecord with the expanded specialSourceFilespec.
	    printf -v specialInstallRecord '%q' "$specialSourceFilespec"
	    specialCommand="$specialInstallerCommand"
	fi

	submitInstallCommand \
	    "$specialCommand $specialInstallRecord" \
	    "${decoration["${prefix}:$specialInstallRecord"]}"
    done
}
installStartmenu()
{
    installSpecialInstall startmenu 'createDesktopEntry --system-wide' 'addToStartMenu --system-wide' addedStartmenuEntries "$@"
}
installUserStartmenu()
{
    installSpecialInstall userstartmenu createDesktopEntry addToStartMenu addedUserStartmenuEntries "$@"
}
installAutostart()
{
    installSpecialInstall autostart 'createDesktopEntry --autostart' addToAutostart addedAutostartEntries "$@"
}

typeRegistry+=([startmenu:]=Startmenu)
typeRegistry+=([userstartmenu:]=UserStartmenu)
typeRegistry+=([autostart:]=Autostart)
typeInstallOrder+=([873]=Startmenu)
typeInstallOrder+=([874]=UserStartmenu)
typeInstallOrder+=([875]=Autostart)
