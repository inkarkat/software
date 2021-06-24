#!/bin/bash source-this-script

configUsageDebBuild()
{
    cat <<'HELPTEXT'
deb-build: items refer to packages that satisfy the build dependencies for a
source package.
HELPTEXT
}

typeRegistry+=([build-dep:]=DebBuild)
typeInstallOrder+=([121]=DebBuild)

if ! exists apt-get; then
    hasDebBuild() { return 98; }
    installDebBuild() { :; }
    isAvailableDebBuild() { return 98; }
    return
fi

typeset -A installedDebBuildDependencies=()
isInstalledDebBuildDependenciesAvailable=
getInstalledDebBuildDependencies()
{
    [ "$isInstalledDebBuildDependenciesAvailable" ] && return

    eval "$(database debBuildDependencies --get-as-dictionary installedDebBuildDependencies --omit-declaration)" || return 1

    [ ${#installedDebBuildDependencies[@]} -gt 0 ] &&
	case ",${DEBUG:-}," in *,setup-software:deb-build,*) echo >&2 "${PS4}setup-software (deb-build): Found installed ${!installedDebBuildDependencies[*]}";; esac

    isInstalledDebBuildDependenciesAvailable=t
}
typeset -A addedDebBuildDependencies=()
hasDebBuild()
{
    local debBuildName="${1:?}"; shift
    if ! getInstalledDebBuildDependencies; then
	messagePrintf >&2 'ERROR: Failed to obtain build dependencies list; skipping %s.\n' "$debBuildName"
	return 99
    fi
    [ "${installedDebBuildDependencies["$debBuildName"]}" ] || [ "${addedDebBuildDependencies["$debBuildName"]}" ]
}

hasDebSrc()
{
    local APT_SOURCES=/etc/apt/sources.list
    grep --quiet -e '^deb-src' "$APT_SOURCES" && return 0

    if askTo --subject 'deb-src' --verb 'are not yet' --state 'enabled in sources.list' --action 'enable them'; then
	local debSrcEnable; printf -v debSrcEnable %q "${projectDir}/lib/enableDebSrc.sh"
	submitInstallCommand "${SUDO}${SUDO:+ }$debSrcEnable $APT_SOURCES"
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
    isQuiet=t hasDebBuild "$@"
}

installDebBuild()
{
    [ ${#addedDebBuildDependencies[@]} -gt 0 ] || return

    local databaseUpdate; printf -v databaseUpdate %q "${scriptDir}/${scriptName}"
    local buildDep; for buildDep in "${!addedDebBuildDependencies[@]}"
    do
	submitInstallCommand \
	    "${SUDO}${SUDO:+ }apt-get${isBatch:+ --assume-yes} build-dep $buildDep && ${databaseUpdate}${isVerbose:+ --verbose} --database debBuildDependencies --add $buildDep" \
	    "${decoration["build-dep:$buildDep"]}"
    done
}
