#!/bin/bash source-this-script

configUsageSnap()
{
    cat <<'HELPTEXT'
snap: items refer to packages from the Snap store that work across many
different Linux distributions, are segregated and update automatically.
HELPTEXT
}

typeset -A installedSnapPackages=()
isInstalledSnapPackagesAvailable=
getInstalledSnapPackages()
{
    [ "$isInstalledSnapPackagesAvailable" ] && return

    local packageName remainder; while IFS=' ' read -r packageName remainder
    do
	case "$packageName" in
	    Name)	    continue;;	# Skip single-line header
	    *)		    installedSnapPackages["$packageName"]=t
			    case ",${DEBUG:-}," in *,setup-software:snap,*) echo >&2 "${PS4}setup-software (snap): Found installed ${packageName}";; esac
			    ;;
	esac
    done < <(snap list --color=never --unicode=never 2>/dev/null)

    isInstalledSnapPackagesAvailable=t
}
hasSnap()
{
    ! getInstalledSnapPackages || [ "${installedSnapPackages["${1:?}"]}" ]
}

typeset -a addedSnapPackages=()
addSnap()
{
    isAvailable snap snapd && addedSnapPackages+=("${1:?}")
}

installSnap()
{
    [ ${#addedSnapPackages[@]} -gt 0 ] || return
    local IFS=' '
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }snap install ${addedSnapPackages[*]}")
}

typeRegistry+=([snap:]=Snap)
typeInstallOrder+=([100]=Snap)
