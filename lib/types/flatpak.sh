#!/bin/bash source-this-script

configUsageFlatpak()
{
    cat <<'HELPTEXT'
flatpak: items consist of a
    REMOTE:NAME
pair that refers to a package NAME from the Flathub repository REMOTE; these
work across many different Linux distributions and are segregated.
HELPTEXT
}

typeset -A installedFlatpakPackages=()
isInstalledFlatpakPackagesAvailable=
getInstalledFlatpakPackages()
{
    [ "$isInstalledFlatpakPackagesAvailable" ] && return
    if ! exists flatpak; then
	# A missing flatpak means that no Flatpak packages have been installed yet.
	isInstalledFlatpakPackagesAvailable=t
	return
    fi

    local exitStatus packageName; while IFS=$'\n' read -r packageName || { exitStatus="$packageName"; break; }	# Exit status from the process substitution (<(flatpak)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedFlatpakPackages["$packageName"]=t
	case ",${DEBUG:-}," in *,setup-software:flatpak,*) echo >&2 "${PS4}setup-software (flatpak): Found installed ${packageName}";; esac
    done < <(flatpak list --columns=application 2>/dev/null; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledFlatpakPackagesAvailable=t
}

typeset -A addedFlatpakPackages=()
typeset -A externallyAddedFlatpakPackages=()
hasFlatpak()
{
    local flatpakRemote="${1%%:*}"
    local flatpakPackageName="${1#"${flatpakRemote}:"}"
    if [ -z "$flatpakRemote" -o -z "$flatpakPackageName" ]; then
	printf >&2 'ERROR: Invalid flatpak item: "flatpak:%s"\n' "$1"
	exit 3
    fi

    if ! getInstalledFlatpakPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed Flatpak package list; skipping %s.\n' "$flatpakPackageName"
	return 99
    fi
    [ "${installedFlatpakPackages["$flatpakPackageName"]}" ] || \
	[ "${addedFlatpakPackages["$flatpakPackageName"]}" ] || \
	[ "${externallyAddedFlatpakPackages["$flatpakPackageName"]}" ]
}

typeset -A addedFlatpakPackagesByRemote=()
addFlatpak()
{
    local flatpakRemote="${1%%:*}"
    local flatpakPackageName="${1#"${flatpakRemote}:"}"

    isAvailableOrUserAcceptsNative flatpak || return $?
    isAvailableOrUserAcceptsNative gnome-software-plugin-flatpak || return $?

    preinstallHook "$flatpakPackageName"
    addedFlatpakPackages["$flatpakPackageName"]=t
    addedFlatpakPackagesByRemote["$flatpakRemote"]="${addedFlatpakPackagesByRemote["$flatpakRemote"]}${addedFlatpakPackagesByRemote["$flatpakRemote"]:+ }$flatpakPackageName"
    postinstallHook "$flatpakPackageName"
}

isAvailableFlatpak()
{
    isQuiet=t hasFlatpak "$@"
}

installFlatpak()
{
    local IFS=' '

    [ ${#addedFlatpakPackages[@]} -gt 0 ] || return

    local flatpakRemote; for flatpakRemote in "${!addedFlatpakPackagesByRemote[@]}"
    do
	submitInstallCommand "${SUDO}${SUDO:+ }flatpak install $flatpakRemote ${addedFlatpakPackagesByRemote["$flatpakRemote"]}"
    done
}

typeRegistry+=([flatpak:]=Flatpak)
typeInstallOrder+=([201]=Flatpak)
