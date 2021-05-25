#!/bin/bash source-this-script

configUsageYum()
{
    cat <<'HELPTEXT'
yum: items refer to Redhat packages installed via yum.
HELPTEXT
}

typeRegistry+=([yum:]=Yum)
typeInstallOrder+=([102]=Yum)

if exists yum; then
    nativeRegistry+=(Yum)
else
    hasYum() { return 98; }
    installYum() { :; }
    isAvailableYum() { return 98; }
    return
fi

didRepoqueryCheck=
haveRepoquery()
{
    # repoquery is provided by the optional yum-utils package; it may not be
    # there yet. Unlike with pip3 or npm, its non-existence does not imply that
    # no packages have yet been installed, so we need to have this dependency to
    # do any Yum install operations.
    exists repoquery && return 0
    if [ ! "$didRepoqueryCheck" ]; then
	didRepoqueryCheck=t
	askToInstall 'yum-utils' || return 1

	preinstallHook 'yum-utils'
	preInstall --execute
	    # Unless we're directly executing the generated install commands, we
	    # must not produce anything on stdout, as that might get captured by
	    # a client and then attempted to be executed as install commands.
	    local redirectStdoutToStderr; [ "$isExecute" ] || redirectStdoutToStderr='>&2'

	    eval "\$SUDO yum${isBatch:+ --assumeyes} install yum-utils${redirectStdoutToStderr:+ }${redirectStdoutToStderr}"
	postinstallHook 'yum-utils'
	postInstall --execute
    fi
    exists repoquery
}

typeset -A installedYumPackages=()
isInstalledYumPackagesAvailable=
getInstalledYumPackages()
{
    [ "$isInstalledYumPackagesAvailable" ] && return
    haveRepoquery || return 1

    # If another update / installation is happening, repoquery blocks with
    # "Existing lock /var/run/yum.pid: another copy is running as pid N."
    # Try to detect this though the PID file existence, and then abort the
    # querying after 2 seconds (which should give the warning just once, yet
    # allow for successful querying of installed packages should we be wrong
    # about the PID file or it suddenly vanished.
    unset -f repoquery; [ -e /var/run/yum.pid ] && repoquery() { timeout 2s repoquery "$@"; }

    local exitStatus package; while IFS=$'\n' read -r package || { exitStatus="$package"; break; }	# Exit status from the process substitution (<(repoquery)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedYumPackages["$package"]=t
	case ",${DEBUG:-}," in *,setup-software:native,*) echo >&2 "${PS4}setup-software (native): Found $package";; esac
    done < <(repoquery --qf '%{name}' --installed -a; printf %d "$?")
    if [ $exitStatus -eq 124 ]; then
	echo >&2 'ERROR: Failed to obtain installed native package list due to another concurrent yum execution; aborting.'
	exit 3
    fi
    [ $exitStatus -eq 0 -a ${#installedYumPackages[@]} -gt 0 ] && isInstalledYumPackagesAvailable=t
}

typeset -A addedYumPackages=()
typeset -A externallyAddedYumPackages=()
hasYum()
{
    local packageName="${1:?}"; shift
    if ! getInstalledYumPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed native package list; skipping %s.\n' "$packageName"
	return 99
    fi

    [ "${installedYumPackages["$packageName"]}" ] || [ "${addedYumPackages["$packageName"]}" ] || [ "${externallyAddedYumPackages["$packageName"]}" ]
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
    isQuiet=t hasYum "$@"
}

installYum()
{
    [ ${#addedYumPackages[@]} -gt 0 ] || return
    local IFS=' '
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }yum${isBatch:+ --assumeyes} install ${!addedYumPackages[*]}")
}
