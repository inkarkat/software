#!/bin/bash source-this-script

configUsageAptRemove()
{
    cat <<'HELPTEXT'
apt-remove: items refer to Debian packages to be uninstalled via apt.
HELPTEXT
}

typeRegistry+=([apt-remove:]=AptRemove)
typeInstallOrder+=([10]=AptRemove)

if ! exists apt; then
    hasAptRemove() { return 98; }
    installAptRemove() { :; }
    isAvailableAptRemove() { return 98; }
    return
fi

typeset -A removedAptPackages=()
typeset -A externallyRemovedAptPackages=()
hasAptRemove()
{
    local packageName="${1:?}"; shift
    if ! getInstalledAptPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed native package list; skipping %s.\n' "$packageName"
	return 99
    fi

    [ ! "${installedAptPackages["$packageName"]}" ] || [ "${removedAptPackages["$packageName"]}" ] || [ "${externallyRemovedAptPackages["$packageName"]}" ]
}

addAptRemove()
{
    local packageName="${1:?}"; shift
    removedAptPackages["$packageName"]=t
    unset "installedAptPackages[$packageName]"	# The package won't be available any longer.
}

isAvailableAptRemove()
{
    isQuiet=t hasAptRemove "$@"
}

installAptRemove()
{
    [ ${#removedAptPackages[@]} -gt 0 ] || return
    local IFS=' '
    submitInstallCommand "${SUDO}${SUDO:+ }apt${isBatch:+ --assume-yes} remove ${!removedAptPackages[*]}"
}
