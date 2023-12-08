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
configUsageAptUpgrade()
{
    cat <<'HELPTEXT'
apt-upgrade: items refer to Debian packages to be attempted to be upgraded
(i.e. install a version now selected by the package management (if such exists,
e.g. after configuring a different repository) over an existing installation)
via apt.
HELPTEXT
}

typeRegistry+=([apt-remove:]=AptRemove)
typeRegistry+=([apt-reinstall:]=AptReinstall)
typeRegistry+=([apt-upgrade:]=AptUpgrade)
typeInstallOrder+=([9]=AptRemove)
typeInstallOrder+=([10]=AptReinstall)
typeInstallOrder+=([199]=AptUpgrade)

if ! exists apt; then
    hasAptRemove() { return 98; }
    hasAptReinstall() { return 98; }
    hasAptUpgrade() { return 98; }
    installAptRemove() { :; }
    installAptReinstall() { :; }
    installAptUpgrade() { :; }
    isAvailableAptRemove() { return 98; }
    isAvailableAptReinstall() { return 98; }
    isAvailableAptUpgrade() { return 98; }
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

    [ ! "${installedAptPackages["$packageName"]}" ] \
	|| [ "${removedAptPackages["$packageName"]}" ] || [ "${externallyRemovedAptPackages["$packageName"]}" ]
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
hasAptUpgrade()
{
    local packageName="${1:?}"; shift
    if ! getInstalledAptPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed native package list; skipping %s.\n' "$packageName"
	return 99
    fi

    [ ! "${installedAptPackages["$packageName"]}" ] \
	|| [ "${removedAptPackages["$packageName"]}" ] || [ "${externallyRemovedAptPackages["$packageName"]}" ]
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
addAptUpgrade()
{
    local packageName="${1:?}"; shift
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
isAvailableAptUpgrade()
{
    isQuiet=t hasAptUpgrade "$@"
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
installAptUpgrade()
{
    # Noop; the actual actions are done by installApt().
    :
}
