#!/bin/bash source-this-script

typeset -A installedAptPackages=()
isInstalledAptPackagesAvailable=
getInstalledAptPackages()
{
    [ "$isInstalledAptPackagesAvailable" ] && return

    local exitStatus package; while IFS=$'\n' read -r package || { exitStatus="$package"; break; }	# Exit status from the process substitution (<(dpkg-package-list)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedAptPackages["$package"]=t
	case ",${DEBUG:-}," in *,setup-software:native,*) echo >&2 "${PS4}setup-software (native): Found $package";; esac
    done < <(dpkg-package-list; printf %d "$?")
    [ $exitStatus -eq 0 -a ${#installedAptPackages[@]} -gt 0 ] && isInstalledAptPackagesAvailable=t
}
typeset -A addedAptPackages=()

hasApt()
{
    local packageName="${1:?}"; shift
    if ! getInstalledAptPackages; then
	echo >&2 "ERROR: Failed to obtain installed native package list; skipping ${packageName}."
	return 99
    fi

    [ "${installedAptPackages["$packageName"]}" ] || [ "${addedAptPackages["$packageName"]}" ]
}

addApt()
{
    local packageName="${1:?}"; shift
    preinstallHook "$packageName"
    addedAptPackages["$packageName"]=t
    postinstallHook "$packageName"
}

isAvailableApt()
{
    hasApt "$@" 2>/dev/null
}

installApt()
{
    [ ${#addedAptPackages[@]} -gt 0 ] || return
    local IFS=' '
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }apt install ${!addedAptPackages[*]}")
}
