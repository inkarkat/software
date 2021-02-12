#!/bin/bash source-this-script

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
hasDebBuild()
{
    ! getInstalledDebBuildDependencies|| [ "${installedDebBuildDependencies["${1:?}"]}" ]
}

typeset -a addedDebBuildDependencies=()
addDebBuild()
{
    hasDebSrc && addedDebBuildDependencies+=("${1:?}")
}

installDebBuild()
{
    [ ${#addedDebBuildDependencies[@]} -gt 0 ] || return

    local databaseUpdate; printf -v databaseUpdate %q "${scriptDir}/${scriptName}"
    local buildDep; for buildDep in "${addedDebBuildDependencies[@]}"
    do
	toBeInstalledCommands+=("${SUDO}${SUDO:+ }apt-get build-dep $buildDep && ${databaseUpdate}${isVerbose:+ --verbose} --database debBuildDependencies --add $buildDep")
    done
}

typeRegistry+=([build-dep:]=DebBuild)
typeInstallOrder+=([20]=DebBuild)
