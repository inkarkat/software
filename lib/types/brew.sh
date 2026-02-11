#!/bin/bash source-this-script

configUsageBrew()
{
    cat <<'HELPTEXT'
brew: items refer to the Homebrew package manager.
HELPTEXT
}

typeset -A installedBrewPackages=()
isInstalledBrewPackagesAvailable=
getInstalledBrewPackages()
{
    [ "$isInstalledBrewPackagesAvailable" ] && return

    typeset -a brewLauncher=()
    if exists brew; then
	# If the brew command is provided, use it.
	:
    elif [ ! -d ~linuxbrew ]; then
	# A missing brew home directory means that no Homebrew itself has been installed
	# yet.
	isInstalledBrewPackagesAvailable=t
	return
    elif getent passwd linuxbrew >/dev/null 2>&1 && sudo --user linuxbrew bash -c '[ -x /home/linuxbrew/.linuxbrew/bin/brew ]'; then
	# Homebrew has already been installed under a special "linuxbrew" service
	# account, but our user doesn't (yet) have access to it. (A new login is
	# required to apply the group membership in "linuxbrew", and the brew wrapper
	# command is also only created on the next login.)
	# Need to use the dedicated linuxbrew user to access it (so far).
	brewLauncher=(sudo --user linuxbrew --set-home --login)
    else
	# A missing brew command (even though the home directory might already exist)
	# means that Homebrew hasn't been fully installed yet.
	isInstalledBrewPackagesAvailable=t
	return
    fi

    local exitStatus packageName remainder; while IFS=' ' read -r packageName remainder || { exitStatus="$packageName"; break; }	# Exit status from the process substitution (<(brew)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	case "$packageName" in
	    '==> '*)	    continue;;	# Skip formulae / casks headers.
	    '')		    continue;;	# Skip empty lines.
	    *)		    installedBrewPackages["$packageName"]=t
			    case ",${DEBUG:-}," in *,setup-software:brew,*) echo >&2 "${PS4}setup-software (brew): Found installed ${packageName}";; esac
			    ;;
	esac
    done < <("${brewLauncher[@]}" brew list -1 --quiet 2>/dev/null; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledBrewPackagesAvailable=t
}

typeset -A addedBrewPackages=()
typeset -A externallyAddedBrewPackages=()
hasBrew()
{
    local brewPackageName="${1:?}"; shift
    if ! getInstalledBrewPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed Homebrew package list; skipping %s.\n' "$brewPackageName"
	return 99
    fi

    [ "${installedBrewPackages["$brewPackageName"]}" ] || [ "${addedBrewPackages["$brewPackageName"]}" ] || [ "${externallyAddedBrewPackages["$brewPackageName"]}" ]
}

addBrew()
{
    local brewPackageName="${1:?}"; shift
    isAvailableOrUserAcceptsGroup brew "${projectDir}/lib/definitions/brew" 'Homebrew package manager' || return $?

    preinstallHook Brew "$brewPackageName"
    addedBrewPackages["$brewPackageName"]=t
    postinstallHook Brew "$brewPackageName"
}

isAvailableBrew()
{
    isQuiet=t hasBrew "$@"
}

installBrew()
{
    [ ${#addedBrewPackages[@]} -gt 0 ] || return
    local IFS=' '
    submitInstallCommand "${isBatch:+ NONINTERACTIVE=1 }brew install ${!addedBrewPackages[*]}"
}

typeRegistry+=([brew:]=Brew)
typeInstallOrder+=([600]=Brew)
