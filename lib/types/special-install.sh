#!/bin/bash source-this-script

configUsageSpecialInstall()
{
    local prefix="${1:?}"; shift
    local specialWhere="${1:?}"; shift

    cat <<HELPTEXT
${prefix}: items consist of createDesktopEntry arguments
    -e|--exec COMMAND [-n|--name NAME] [-i|--icon ICON] [-c|--comment COMMENT] [-t|--category CATEGORY [-t ...]] DESKTOP-ENTRY
and the resulting desktop entry is added to ${specialWhere}.
HELPTEXT
}
configUsageStartmenu()
{
    configUsageSpecialInstall startmenu "the user's start menu"
}
configUsageAutostart()
{
    configUsageSpecialInstall autostart "the user's startup applications"
}

typeset -A addedStartmenuEntries=()
typeset -A addedAutostartEntries=()
hasSpecialInstall()
{
    local prefix="${1:?}"; shift
    local specialInstallerCommand="${1:?}"; shift
    local specialInstallEntriesDictName="${1:?}"; shift
    local specialInstallRecord="${1:?}"; shift

    eval "[ \"\${${specialInstallEntriesDictName}[\"\$specialInstallRecord\"]}\" ]" && return 0

    # Delegate the check to the addTo... commands with --check option (which
    # only test the target's existence and do not need a valid source file);
    # createDesktopEntry itself has no such check. These commands encapsulate
    # the destination locations, avoiding that we need to duplicate them here
    # one more.
    eval "set -- $specialInstallRecord"
    local specialName="${!#}"
    local checkCommand="$specialInstallerCommand --check ${specialName%.desktop}.desktop"
    local decoratedCheckCommand="$(decorateCommand "$checkCommand" "${decoration["${prefix}:$specialInstallRecord"]}")"
    eval "$decoratedCheckCommand"
}
hasStartmenu()
{
    hasSpecialInstall startmenu addToStartMenu addedStartmenuEntries "$@"
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
    eval "${specialInstallEntriesDictName}[\"\$specialInstallRecord\"]=t"
    postinstallHook "$specialName"
}
addStartmenu()
{
    addSpecialInstall addedStartmenuEntries "$@"
}
addAutostart()
{
    addSpecialInstall addedAutostartEntries "$@"
}

installSpecialInstall()
{
    local prefix="${1:?}"; shift
    local specialInstallerCommand="${1:?}"; shift
    local specialInstallEntriesDictName="${1:?}"; shift
    eval "[ \${#${specialInstallEntriesDictName}[@]} -gt 0 ]" || return
    eval "typeset -a addedSpecialInstallRecords=\"\${!${specialInstallEntriesDictName}[@]}\""
    local specialInstallRecord; for specialInstallRecord in "${addedSpecialInstallRecords[@]}"
    do

	submitInstallCommand \
	    "$specialInstallerCommand $specialInstallRecord" \
	    "${decoration["${prefix}:$specialInstallRecord"]}"
    done
}
installStartmenu()
{
    installSpecialInstall startmenu createDesktopEntry addedStartmenuEntries "$@"
}
installAutostart()
{
    installSpecialInstall autostart 'createDesktopEntry --autostart' addedAutostartEntries "$@"
}

typeRegistry+=([startmenu:]=Startmenu)
typeRegistry+=([autostart:]=Autostart)
typeInstallOrder+=([872]=Startmenu)
typeInstallOrder+=([873]=Autostart)
