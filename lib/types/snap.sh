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
    if ! exists snap; then
	# A missing snap means that no Snap packages have been installed yet.
	isInstalledSnapPackagesAvailable=t
	return
    fi

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
typeset -A externallyAddedSnapPackages=()
hasSnap()
{
    local snapPackageName="${1:?}"; shift
    if ! getInstalledSnapPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed Snap store package list; skipping %s.\n' "$snapPackageName"
	return 99
    fi
    [ "${installedSnapPackages["$snapPackageName"]}" ] || [ "${addedSnapPackages["$snapPackageName"]}" ] || [ "${externallyAddedSnapPackages["$snapPackageName"]}" ]
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
    isQuiet=t hasSnap "$@"
}

installSnap()
{
    [ ${#addedSnapPackages[@]} -gt 0 ] || return
    local IFS=' '
    submitInstallCommand "${SUDO}${SUDO:+ }snap install ${!addedSnapPackages[*]}"
}

typeRegistry+=([snap:]=Snap)
typeInstallOrder+=([200]=Snap)
