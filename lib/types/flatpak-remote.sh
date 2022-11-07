#!/bin/bash source-this-script

configUsageFlatpakRemote()
{
    cat <<HELPTEXT
flatpak-remote: items consist of a
    REMOTE:LOCATION
pair, where the remote LOCATION will be registered under REMOTE, and then in
turn is referenced by flatpak: items.
Note: Do not use this with a preinstall: prefix, because that could lead to the
flatpak dependency getting installed twice.
HELPTEXT
}

typeset -A installedFlatpakRemotes=()
isInstalledFlatpakRemoteAvailable=
getInstalledFlatpakRemotes()
{
    [ "$isInstalledFlatpakRemoteAvailable" ] && return
    if ! exists flatpak; then
	# A missing flatpak means that no Flatpak remotes have been installed yet.
	isInstalledFlatpakRemoteAvailable=t
	return
    fi

    local exitStatus remoteName; while IFS=$'\n' read -r remoteName || { exitStatus="$remoteName"; break; }	# Exit status from the process substitution (<(flatpak)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	[ -n "$remoteName" ] || continue
	installedFlatpakRemotes["$remoteName"]=t
	case ",${DEBUG:-}," in *,setup-software:flatpak-remote,*) echo >&2 "${PS4}setup-software (flatpak-remote): Found installed ${remoteName}";; esac
    done < <(flatpak remote-list --columns=name 2>/dev/null; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledFlatpakRemoteAvailable=t
}

typeset -A addedFlatpakRemotes=()
hasFlatpakRemote()
{
    local flatpakRemoteName="${1%%:*}"
    local flatpakLocation="${1#"${flatpakRemoteName}:"}"
    if [ -z "$flatpakRemoteName" -o -z "$flatpakLocation" ]; then
	printf >&2 'ERROR: Invalid flatpak-remote item: "flatpak-remote:%s"\n' "$1"
	exit 3
    fi

    if ! getInstalledFlatpakRemotes; then
	messagePrintf >&2 'ERROR: Failed to obtain installed Flatpak remotes list; skipping %s.\n' "$flatpakRemoteName"
	return 99
    fi
    [ "${installedFlatpakRemotes["$flatpakRemoteName"]}" ] || \
	[ "${addedFlatpakRemotes["$flatpakRemoteName"]}" ]
}

addFlatpakRemote()
{
    local flatpakRemoteName="${1%%:*}"
    local flatpakLocation="${1#"${flatpakRemoteName}:"}"

    isAvailableOrUserAcceptsNative flatpak || return $?

    addedFlatpakRemotes["$flatpakRemoteName"]="$flatpakLocation"
}

installFlatpakRemote()
{
    [ ${#addedFlatpakRemotes[@]} -gt 0 ] || return
    local remoteName; for remoteName in "${!addedFlatpakRemotes[@]}"
    do
	local quotedLocation; printf -v quotedLocation '%q' "${addedFlatpakRemotes["$remoteName"]}"
	submitInstallCommand "${SUDO}${SUDO:+ }flatpak remote-add $remoteName $quotedLocation"
    done
}

typeRegistry+=([flatpak-remote:]=FlatpakRemote)
typeInstallOrder+=([201]=FlatpakRemote)
