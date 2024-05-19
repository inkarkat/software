#!/bin/bash source-this-script

configUsageSpecialInstallUrl()
{
    local prefix="${1:?}"; shift
    local specialWhere="${1:?}"; shift

    : ${INSTALL_REPO:=~/install}
    cat <<HELPTEXT
${prefix}: items consist of
    [MAX-AGE[SUFFIX]:][[SUBDIR/]NAME/]FILE-GLOB:[URL [...]]
If ${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/FILE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, URL(s)
(first that succeeds) will be downloaded (and put into
${INSTALL_REPO}/* if it exists) and added to ${specialWhere}.
HELPTEXT
}
configUsageIconUrl()
{
    configUsageSpecialInstallUrl icon+url "the system-wide application icons"
}
configUsageUserIconUrl()
{
    configUsageSpecialInstallUrl usericon+url "the user's application icons"
}
configUsageStartmenuUrl()
{
    configUsageSpecialInstallUrl startmenu+url "the system-wide start menu"
}
configUsageUserStartmenuUrl()
{
    configUsageSpecialInstallUrl userstartmenu+url "the user's start menu"
}
configUsageAutostartUrl()
{
    configUsageSpecialInstallUrl autostart+url "the user's startup applications"
}

getSpecialInstallCommandFromUrlRecord()
{
    local specialDownloadInstallerCommand="${1:?}"; shift
    local specialInstallUrlRecord="${1:?}"; shift

    local maxAge=
    local specialNamePackageGlobUrl="$specialInstallUrlRecord"
    if [[ "$specialNamePackageGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	maxAge="${BASH_REMATCH[0]%:}"
	specialNamePackageGlobUrl="${specialNamePackageGlobUrl#"${BASH_REMATCH[0]}"}"
    fi
    local urlList="${specialNamePackageGlobUrl#*:}"
    local specialNameAndPackageGlob="${specialNamePackageGlobUrl%:$urlList}"
    local packageGlob="${specialNameAndPackageGlob##*/}"
    local specialName="${specialNameAndPackageGlob%"$packageGlob"}"
    local outputNameArg=; isglob "$packageGlob" || printf -v outputNameArg %q "$packageGlob"
    printf -v packageGlob %q "$packageGlob"
    specialName="${specialName%/}"
    printf -v specialName %q "$specialName"
    typeset -a urls=(); IFS=' ' read -r -a urls <<<"$urlList"
    local urlArgs=''; [ ${#urls[@]} -gt 0 ] && printf -v urlArgs ' --url %q' "${urls[@]}"

    printf '%s\n' "${specialDownloadInstallerCommand}${isBatch:+ --batch}${specialName:+ --application-name }${specialName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}"
}

typeset -A addedIconUrlPackages=()
typeset -A addedUserIconUrlPackages=()
typeset -A addedStartmenuUrlPackages=()
typeset -A addedUserStartmenuUrlPackages=()
typeset -A addedAutostartUrlPackages=()
hasSpecialInstallUrl()
{
    local prefix="${1:?}"; shift
    local specialDownloadInstallerCommand="${1:?}"; shift
    local specialInstallUrlPackagesDictName="${1:?}"; shift
    local specialInstallUrlRecord="${1:?}"; shift

    if [[ ! "$specialInstallUrlRecord" =~ ^[^:]+: ]]; then
	printf >&2 'ERROR: Invalid %s item: "%s:%s"\n' "$prefix" "$prefix" "$specialInstallUrlRecord"
	exit 3
    fi

    local -n specialInstallUrlPackages=$specialInstallUrlPackagesDictName
    [ "${specialInstallUrlPackages["$specialInstallUrlRecord"]}" ] && return 0

    # As there's no (fixed) destination filespec to test, we need to run the
    # special download-installer command with the --check option. This will
    # already download the file, so it's quite expensive for a test. However,
    # this type will mostly be used as a postinstall: item, so it will only run
    # after the application itself got installed (and then both the check and
    # the installation will happen right after each other).
    local checkCommand="$(getSpecialInstallCommandFromUrlRecord "$specialDownloadInstallerCommand --check" "$specialInstallUrlRecord")"
    [ -n "$checkCommand" ] || exit 3
    local decoratedCheckCommand="$(decorateCommand "$checkCommand" "${decoration["${prefix}:$specialInstallUrlRecord"]}")"
    eval "$decoratedCheckCommand"
}
hasIconUrl()
{
    hasSpecialInstallUrl icon+url 'icon-download-installer --system-wide' addedIconUrlPackages "$@"
}
hasUserIconUrl()
{
    hasSpecialInstallUrl usericon+url icon-download-installer addedIconUrlPackages "$@"
}
hasStartmenuUrl()
{
    hasSpecialInstallUrl startmenu+url desktop-entry-download-installer addedStartmenuUrlPackages "$@"
}
hasAutostartUrl()
{
    hasSpecialInstallUrl autostart+url 'desktop-entry-download-installer --autostart' addedAutostartUrlPackages "$@"
}

addSpecialInstallUrl()
{
    local specialInstallUrlPackagesDictName="${1:?}"; shift
    local specialInstallUrlRecord="${1:?}"; shift

    # Note: Do not support pre-/postinstall hooks here (yet), as there's no good
    # short "name" that we could use (and likely no need for such simple things
    # as icons and desktop entries).
    local -n specialInstallUrlPackages=$specialInstallUrlPackagesDictName
    specialInstallUrlPackages["$specialInstallUrlRecord"]=t
}
addIconUrl()
{
    addSpecialInstallUrl addedIconUrlPackages "$@"
}
addUserIconUrl()
{
    addSpecialInstallUrl addedUserIconUrlPackages "$@"
}
addStartmenuUrl()
{
    addSpecialInstallUrl addedStartmenuUrlPackages "$@"
}
addUserStartmenuUrl()
{
    addSpecialInstallUrl addedUserStartmenuUrlPackages "$@"
}
addAutostartUrl()
{
    addSpecialInstallUrl addedAutostartUrlPackages "$@"
}

installSpecialInstallUrl()
{
    local prefix="${1:?}"; shift
    local specialDownloadInstallerCommand="${1:?}"; shift
    local specialInstallUrlPackagesDictName="${1:?}"; shift
    local -n specialInstallUrlPackages=$specialInstallUrlPackagesDictName
    [ ${#specialInstallUrlPackages[@]} -gt 0 ] || return
    local specialInstallUrlRecord; for specialInstallUrlRecord in "${!specialInstallUrlPackages[@]}"
    do

	submitInstallCommand \
	    "$(getSpecialInstallCommandFromUrlRecord "$specialDownloadInstallerCommand" "$specialInstallUrlRecord")" \
	    "${decoration["${prefix}:$specialInstallUrlRecord"]}"
    done
}
installIconUrl()
{
    installSpecialInstallUrl icon+url 'icon-download-installer --system-wide' addedIconUrlPackages "$@"
}
installUserIconUrl()
{
    installSpecialInstallUrl usericon+url icon-download-installer addedIconUrlPackages "$@"
}
installStartmenuUrl()
{
    installSpecialInstallUrl startmenu+url 'desktop-entry-download-installer --system-wide' addedStartmenuUrlPackages "$@"
}
installUserStartmenuUrl()
{
    installSpecialInstallUrl userstartmenu+url desktop-entry-download-installer addedUserStartmenuUrlPackages "$@"
}
installAutostartUrl()
{
    installSpecialInstallUrl autostart+url 'desktop-entry-download-installer --autostart' addedAutostartUrlPackages "$@"
}

typeRegistry+=([icon+url:]=IconUrl)
typeRegistry+=([usericon+url:]=UserIconUrl)
typeRegistry+=([startmenu+url:]=StartmenuUrl)
typeRegistry+=([userstartmenu+url:]=UserStartmenuUrl)
typeRegistry+=([autostart+url:]=AutostartUrl)
typeInstallOrder+=([891]=IconUrl)
typeInstallOrder+=([892]=UserIconUrl)
typeInstallOrder+=([893]=StartmenuUrl)
typeInstallOrder+=([894]=UserStartmenuUrl)
typeInstallOrder+=([895]=AutostartUrl)
