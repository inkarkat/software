#!/bin/bash source-this-script

configUsageYumGroup()
{
    cat <<'HELPTEXT'
yum-group: items refer to Redhat package groups installed via "yum group".
HELPTEXT
}

typeRegistry+=([yum-group:]=YumGroup)
typeInstallOrder+=([212]=YumGroup)

if ! exists yum; then
    hasYumGroup() { return 98; }
    installYumGroup() { :; }
    isAvailableYumGroup() { return 98; }
    return
fi

typeset -A installedYumGroups=()
isInstalledYumGroupsAvailable=
getInstalledYumGroups()
{
    [ "$isInstalledYumGroupsAvailable" ] && return

    # If another update / installation is happening, yum blocks with
    # "Existing lock /var/run/yum.pid: another copy is running as pid N."
    # Try to detect this though the PID file existence, and then abort the
    # querying after 2 seconds (which should give the warning just once, yet
    # allow for successful querying of installed packages should we be wrong
    # about the PID file or it suddenly vanished.
    typeset -a yumCommand=(yum)
    [ -e /var/run/yum.pid ] && yumCommand=(timeout 2s yum)

    local exitStatus line isInInstalledSection=; while IFS=$'\n' read -r line || { exitStatus="$line"; break; }	# Exit status from the process substitution (<(yum)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	if [[ "$line" =~ ^Installed\ .*Groups:$ ]]; then
	    isInInstalledSection=t
	elif [[ "$line" =~ ^\ +[^\ ] ]]; then
	    if [ "$isInInstalledSection" ]; then
		local group="${line##+( )}"
		installedYumGroups["$group"]=t
		case ",${DEBUG:-}," in *,setup-software:yum-group,*) echo >&2 "${PS4}setup-software (yum-group): Found $group";; esac
	    fi
	else
	    isInInstalledSection=
	fi
    done < <(LC_ALL=C "${yumCommand[@]}" groups list 2>/dev/null; printf %d "$?")
    if [ $exitStatus -eq 124 ]; then
	echo >&2 'ERROR: Failed to obtain installed yum groups due to another concurrent yum execution; aborting.'
	exit 3
    fi
    [ $exitStatus -eq 0 ] && isInstalledYumGroupsAvailable=t
}

typeset -A addedYumGroups=()
typeset -A externallyAddedYumGroups=()
hasYumGroup()
{
    local groupName="${1:?}"; shift
    if ! getInstalledYumGroups; then
	messagePrintf >&2 'ERROR: Failed to obtain installed yum groups; skipping %s.\n' "$groupName"
	return 99
    fi

    [ "${installedYumGroups["$groupName"]}" ] || [ "${addedYumGroups["$groupName"]}" ] || [ "${externallyAddedYumGroups["$groupName"]}" ]
}

addYumGroup()
{
    local groupName="${1:?}"; shift
    preinstallHook "$groupName"
    addedYumGroups["$groupName"]=t
    postinstallHook "$groupName"
}

isAvailableYumGroup()
{
    isQuiet=t hasYumGroup "$@"
}

installYumGroup()
{
    [ ${#addedYumGroups[@]} -gt 0 ] || return
    printf -v quotedYumGroups '%q ' "${!addedYumGroups[@]}"; quotedYumGroups="${quotedYumGroups% }"
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }yum${isBatch:+ --assumeyes} group install ${quotedYumGroups}")
}
