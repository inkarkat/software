#!/bin/bash source-this-script

configUsageYum()
{
    cat <<'HELPTEXT'
yum: items refer to Redhat packages installed via yum.
HELPTEXT
}

typeRegistry+=([yum:]=Yum)
typeInstallOrder+=([12]=Yum)

if exists yum; then
    nativeRegistry+=(Yum)
else
    hasYum() { return 98; }
    installYum() { :; }
    return
fi

typeset -A installedYumPackages=()
isInstalledYumPackagesAvailable=
getInstalledYumPackages()
{
    [ "$isInstalledYumPackagesAvailable" ] && return

    local exitStatus package; while IFS=$'\n' read -r package || { exitStatus="$package"; break; }	# Exit status from the process substitution (<(repoquery)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedYumPackages["$package"]=t
	case ",${DEBUG:-}," in *,setup-software:native,*) echo >&2 "${PS4}setup-software (native): Found $package";; esac
    done < <(repoquery --qf '%{name}' --installed -a; printf %d "$?")
    [ $exitStatus -eq 0 -a ${#installedYumPackages[@]} -gt 0 ] && isInstalledYumPackagesAvailable=t
}
typeset -A addedYumPackages=()

hasYum()
{
    local packageName="${1:?}"; shift
    if ! getInstalledYumPackages; then
	echo >&2 "ERROR: Failed to obtain installed native package list; skipping ${packageName}."
	return 99
    fi

    [ "${installedYumPackages["$packageName"]}" ] || [ "${addedYumPackages["$packageName"]}" ]
}

addYum()
{
    local packageName="${1:?}"; shift
    preinstallHook "$packageName"
    addedYumPackages["$packageName"]=t
    postinstallHook "$packageName"
}

isAvailableYum()
{
    hasYum "$@" 2>/dev/null
}

installYum()
{
    [ ${#addedYumPackages[@]} -gt 0 ] || return
    local IFS=' '
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }yum install ${!addedYumPackages[*]}")
}
