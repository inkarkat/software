#!/bin/bash source-this-script

configUsageApt()
{
    cat <<'HELPTEXT'
apt: items refer to Debian packages installed via apt.
HELPTEXT
}

typeRegistry+=([apt:]=Apt)
typeInstallOrder+=([101]=Apt)

if exists apt; then
    nativeRegistry+=(Apt)
else
    hasApt() { return 98; }
    installApt() { :; }
    isAvailableApt() { return 98; }
    return
fi

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
typeset -A externallyAddedAptPackages=()
hasApt()
{
    local packageName="${1:?}"; shift
    if ! getInstalledAptPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed native package list; skipping %s.\n' "$packageName"
	return 99
    fi

    [ "${installedAptPackages["$packageName"]}" ] || [ "${addedAptPackages["$packageName"]}" ] || [ "${externallyAddedAptPackages["$packageName"]}" ]
}

addApt()
{
    local packageName="${1:?}"; shift
    preinstallHook Apt "$packageName"
    addedAptPackages["$packageName"]=t
    postinstallHook Apt "$packageName"
}

isAvailableApt()
{
    isQuiet=t hasApt "$@"
}

installApt()
{
    [ ${#addedAptPackages[@]} -gt 0 ] || return
    local IFS=' '
    submitInstallCommand "${SUDO}${SUDO:+ }apt${isBatch:+ --assume-yes} install ${!addedAptPackages[*]}"
}
