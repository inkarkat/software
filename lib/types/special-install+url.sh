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
    configUsageSpecialInstallUrl icon+url "the user's application icons"
}
configUsageStartmenuUrl()
{
    configUsageSpecialInstallUrl startmenu+url "the user's start menu"
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

    printf '%s\n' "${specialDownloadInstallerCommand}${isBatch:+ --batch} ${specialName:+ --application-name }${specialName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}"
}

typeset -A addedIconUrlPackages=()
typeset -A addedStartmenuUrlPackages=()
typeset -A addedAutostartUrlPackages=()
hasSpecialInstallUrl()
{
    local specialInstallUrlPackagesDictName="${1:?}"; shift
    local specialInstallUrlRecord="${1:?}"; shift
    local destinationFilespec="${specialInstallUrlRecord%%:*}"
    if [[ "$destinationFilespec" =~ ^(.*)/\.(/.*)?$ ]]; then
	destinationFilespec="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    fi

    [ -e "$destinationFilespec" ] || eval "[ \"\${${specialInstallUrlPackagesDictName}[\"\$specialInstallUrlRecord\"]}\" ]"
}
hasIconUrl()
{
    hasSpecialInstallUrl addedIconUrlPackages "$@"
}
hasStartmenuUrl()
{
    hasSpecialInstallUrl addedStartmenuUrlPackages "$@"
}
hasAutostartUrl()
{
    hasSpecialInstallUrl addedAutostartUrlPackages "$@"
}

addSpecialInstallUrl()
{
    local specialInstallUrlPackagesDictName="${1:?}"; shift
    local specialInstallUrlRecord="${1:?}"; shift

    # Note: Do not support pre-/postinstall hooks here (yet), as there's no good
    # short "name" that we could use (and likely no need for such simple things
    # as icons and desktop entries).
    eval "${specialInstallUrlPackagesDictName}[\"\$specialInstallUrlRecord\"]=t"
}
addIconUrl()
{
    addSpecialInstallUrl addedIconUrlPackages "$@"
}
addStartmenuUrl()
{
    addSpecialInstallUrl addedStartmenuUrlPackages "$@"
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
    eval "[ \${#${specialInstallUrlPackagesDictName}[@]} -gt 0 ]" || return
    eval "typeset -a addedSpecialInstallUrlRecords=\"\${!${specialInstallUrlPackagesDictName}[@]}\""
    local specialInstallUrlRecord; for specialInstallUrlRecord in "${addedSpecialInstallUrlRecords[@]}"
    do

	submitInstallCommand \
	    "$(getSpecialInstallCommandFromUrlRecord "$specialDownloadInstallerCommand" "$specialInstallUrlRecord")" \
	    "${decoration["${prefix}:$specialInstallUrlRecord"]}"
    done
}
installIconUrl()
{
    installSpecialInstallUrl icon+url icon-download-installer addedIconUrlPackages "$@"
}
installStartmenuUrl()
{
    installSpecialInstallUrl startmenu+url desktop-entry-download-installer addedStartmenuUrlPackages "$@"
}
installAutostartUrl()
{
    installSpecialInstallUrl autostart+url 'desktop-entry-download-installer --autostart' addedAutostartUrlPackages "$@"
}

typeRegistry+=([icon+url:]=IconUrl)
typeRegistry+=([startmenu+url:]=StartmenuUrl)
typeRegistry+=([autostart+url:]=AutostartUrl)
typeInstallOrder+=([891]=IconUrl)
typeInstallOrder+=([892]=StartmenuUrl)
typeInstallOrder+=([893]=AutostartUrl)
