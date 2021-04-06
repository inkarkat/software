#!/bin/bash source-this-script

configUsageSnap()
{
    cat <<'HELPTEXT'
snap: items refer to packages from the Snap store that work across many
different Linux distributions, are segregated and update automatically.
HELPTEXT
}

typeRegistry+=([snap:]=Snap)
typeInstallOrder+=([100]=Snap)

if ! exists snap; then
    hasSnap() { return 98; }
    installSnap() { :; }
    return
fi

typeset -A installedSnapPackages=()
isInstalledSnapPackagesAvailable=
getInstalledSnapPackages()
{
    [ "$isInstalledSnapPackagesAvailable" ] && return

    local exitStatus packageName remainder; while IFS=' ' read -r packageName remainder || { exitStatus="$packageName"; break; }	# Exit status from the process substitution (<(snap)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	case "$packageName" in
	    Name)	    continue;;	# Skip single-line header
	    *)		    installedSnapPackages["$packageName"]=t
			    case ",${DEBUG:-}," in *,setup-software:snap,*) echo >&2 "${PS4}setup-software (snap): Found installed ${packageName}";; esac
			    ;;
	esac
    done < <(snap list --color=never --unicode=never 2>/dev/null; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledSnapPackagesAvailable=t
}
typeset -A addedSnapPackages=()
hasSnap()
{
    local snapPackageName="${1:?}"; shift
    if ! getInstalledSnapPackages; then
	echo >&2 "ERROR: Failed to obtain installed Snap store package list; skipping ${snapPackageName}."
	return 99
    fi
    [ "${installedSnapPackages["$snapPackageName"]}" ] || [ "${addedSnapPackages["$snapPackageName"]}" ]
}

addSnap()
{
    local snapPackageName="${1:?}"; shift
    isAvailableOrUserAcceptsNative snap snapd || return $?

    preinstallHook "$snapPackageName"
    addedSnapPackages["$snapPackageName"]=t
    postinstallHook "$snapPackageName"
}

isAvailableSnap()
{
    hasSnap "$@" 2>/dev/null
}

installSnap()
{
    [ ${#addedSnapPackages[@]} -gt 0 ] || return
    local IFS=' '
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }snap install ${!addedSnapPackages[*]}")
}
