#!/bin/bash source-this-script

configUsageAptRemove()
{
    cat <<'HELPTEXT'
apt-remove: items refer to Debian packages to be uninstalled via apt.
HELPTEXT
}
configUsageAptReinstall()
{
    cat <<'HELPTEXT'
apt-reinstall: items refer to Debian packages to be uninstalled (if installed)
and then installed again (presumably after reconfiguring the package sources)
via apt. Behaves like a normal installation if the package hasn't been
installed.
HELPTEXT
}

typeRegistry+=([apt-remove:]=AptRemove)
typeRegistry+=([apt-reinstall:]=AptReinstall)
typeInstallOrder+=([9]=AptRemove)
typeInstallOrder+=([10]=AptReinstall)

if ! exists apt; then
    hasAptRemove() { return 98; }
    hasAptReinstall() { return 98; }
    installAptRemove() { :; }
    installAptReinstall() { :; }
    isAvailableAptRemove() { return 98; }
    isAvailableAptReinstall() { return 98; }
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
hasAptReinstall()
{
    local packageName="${1:?}"; shift
    if ! getInstalledAptPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed native package list; skipping %s.\n' "$packageName"
	return 99
    fi

    [ "${removedAptPackages["$packageName"]}" ] || [ "${externallyRemovedAptPackages["$packageName"]}" ]
}

addAptRemove()
{
    local packageName="${1:?}"; shift
    removedAptPackages["$packageName"]=t
    unset "installedAptPackages[$packageName]"	# The package won't be available any longer.
}
addAptReinstall()
{
    local packageName="${1:?}"; shift
    removedAptPackages["$packageName"]=t
    addedAptPackages["$packageName"]=t
}

isAvailableAptRemove()
{
    isQuiet=t hasAptRemove "$@"
}
isAvailableAptReinstall()
{
    isQuiet=t hasAptReinstall "$@"
}

installAptRemove()
{
    [ ${#removedAptPackages[@]} -gt 0 ] || return
    local IFS=' '
    submitInstallCommand "${SUDO}${SUDO:+ }apt${isBatch:+ --assume-yes} remove ${!removedAptPackages[*]}"
}
installAptReinstall()
{
    # Noop; the actual actions are done by installAptRemove() and installApt().
    :
}
