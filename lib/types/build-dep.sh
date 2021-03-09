#!/bin/bash source-this-script

configUsageDebBuild()
{
    cat <<'HELPTEXT'
deb-build: items refer to packages that satisfy the build dependencies for a
source package.
HELPTEXT
}

typeset -A installedDebBuildDependencies=()
isInstalledDebBuildDependenciesAvailable=
getInstalledDebBuildDependencies()
{
    [ "$isInstalledDebBuildDependenciesAvailable" ] && return

    eval "$(database debBuildDependencies --get-as-dictionary installedDebBuildDependencies --omit-declaration)" || exit 3

    [ ${#installedDebBuildDependencies[@]} -gt 0 ] &&
	case ",${DEBUG:-}," in *,setup-software:deb-build,*) echo >&2 "${PS4}setup-software (deb-build): Found installed ${!installedDebBuildDependencies[*]}";; esac

    isInstalledDebBuildDependenciesAvailable=t
}
typeset -A addedDebBuildDependencies=()
hasDebBuild()
{
    ! getInstalledDebBuildDependencies || [ "${addedDebBuildDependencies["${1:?}"]}" ] || [ "${installedDebBuildDependencies["${1:?}"]}" ]
}

hasDebSrc()
{
    local APT_SOURCES=/etc/apt/sources.list
    grep --quiet -e '^deb-src' "$APT_SOURCES" && return 0

    if askTo --subject 'deb-src' --verb 'are not yet' --state 'enabled in sources.list' --action 'enable them'; then
	local debSrcEnable; printf -v debSrcEnable %q "${projectDir}/lib/enableDebSrc.sh"
	toBeInstalledCommands+=("${SUDO}${SUDO:+ }$debSrcEnable $APT_SOURCES")
    else
	return 1
    fi
}
addDebBuild()
{
    local debBuildName="${1:?}"; shift
    hasDebSrc || return $?

    preinstallHook "$debBuildName"
    addedDebBuildDependencies["$debBuildName"]=t
    postinstallHook "$debBuildName"
}

isAvailableDebBuild()
{
    local debBuildName="${1:?}"; shift
    getInstalledDebBuildDependencies || return $?
    [ "${installedDebBuildDependencies["$debBuildName"]}" ] || contains "$debBuildName" "${!addedDebBuildDependencies[@]}"
}

installDebBuild()
{
    [ ${#addedDebBuildDependencies[@]} -gt 0 ] || return

    local databaseUpdate; printf -v databaseUpdate %q "${scriptDir}/${scriptName}"
    local buildDep; for buildDep in "${!addedDebBuildDependencies[@]}"
    do
	toBeInstalledCommands+=("${SUDO}${SUDO:+ }apt-get build-dep $buildDep && ${databaseUpdate}${isVerbose:+ --verbose} --database debBuildDependencies --add $buildDep")
    done
}

typeRegistry+=([build-dep:]=DebBuild)
typeInstallOrder+=([20]=DebBuild)
