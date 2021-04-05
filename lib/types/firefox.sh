#!/bin/bash source-this-script

configUsageFirefoxAddon()
{
    cat <<'HELPTEXT'
firefox: items consist of a
    [PROFILE-NAME]:ADDON-ID:ADDON-URL
triplet.
It checks the Firefox PROFILE-NAME / default profile for ADDON-ID and if that
isn't installed yet uses ADDON-URL to launch the right Firefox instance for
(manual) installation of the add-on.
HELPTEXT
}

readonly FIREFOX_PROFILES_DIRSPEC=~/.mozilla/firefox

typeset -A installedFirefoxProfileAddonIds=()
typeset -A isInstalledFirefoxAddonsAvailable=()
getInstalledFirefoxAddons()
{
    local profileName="${1:?}"; shift
    [ "${isInstalledFirefoxAddonsAvailable["$profileName"]}" ] && return
    local addonsConfigFilespec="${1:?}/addons.json"; shift

    local exitStatus id; while IFS=$'\n' read -r id || { exitStatus="$id"; break; }	# Exit status from the process substitution (<(jq)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedFirefoxProfileAddonIds["$profileName $id"]=t
	case ",${DEBUG:-}," in *,setup-software:firefox,*) echo >&2 "${PS4}setup-software (firefox): Found $id installed in profile $profileName";; esac
    done < <(jq --raw-output '.addons | .[] | .id' "$addonsConfigFilespec"; printf %d "$?")
    if [ $exitStatus -ne 0 ]; then
	echo >&2 "ERROR: Failed to obtain Firefox installed add-on list for profile ${profileName}."
	return 1
    fi

    isInstalledFirefoxAddonsAvailable["$profileName"]=t
}
typeset -A addedFirefoxAddons=()
hasFirefoxAddon()
{
    local profileName addonId addonUrl
    IFS=: read -r profileName addonId addonUrl <<<"${1:?}"
    if [ -z "$addonId" -o -z "$addonUrl" ]; then
	printf >&2 'ERROR: Invalid firefox item: "firefox:%s"\n' "$1"
	exit 3
    fi

    [ "${addedFirefoxAddons["$1"]}" ] && return 0	# This add-on has already been selected for installation.

    local _disabledNoGlob=
    case $- in
	*f*)    set +f; _disabledNoGlob=t;;
    esac
	if [ -z "$profileName" ]; then
	    typeset -a existingProfileDirspecs=("$FIREFOX_PROFILES_DIRSPEC"/*.default?(-release))
	else
	    typeset -a existingProfileDirspecs=("$FIREFOX_PROFILES_DIRSPEC"/*."$profileName")
	fi
    [ "${_disabledNoGlob:-}" ] && set -f; unset _disabledNoGlob

    local configDirspec="${existingProfileDirspecs[0]}"
    [ -d "$configDirspec" ] || return 99 # No such Firefox profile.
    if [ -z "$profileName" ]; then
	profileName="${configDirspec##*.}"
	firefoxDefaultProfileName="$profileName"
    fi

    getInstalledFirefoxAddons "$profileName" "$configDirspec" || return 99
    [ "${installedFirefoxProfileAddonIds["${profileName} ${addonId}"]}" ]
}

addFirefoxAddon()
{
    local firefoxAddonRecord="${1:?}"; shift
    local addonId="${firefoxAddonRecord#*:}"; addonId="${addonId%%:*}"
    exists firefox || return $?

    preinstallHook "$addonId"
    addedFirefoxAddons["$firefoxAddonRecord"]=t
    postinstallHook "$addonId"
}

isAvailableFirefoxAddon()
{
    local profileNameAndId="${1:?}"; shift
    local queriedProfileName="${profileNameAndId%%:*}"; shift
    local queriedId="${profileNameAndId#"${queriedProfileName}:"}"; shift

    hasFirefoxAddon "${queriedProfileName}:dummyId:dummyUrl"	# Obtain the addons for the queried profile.
    [ -z "$queriedProfileName" ] && queriedProfileName="${firefoxDefaultProfileName:?}"
    [ "${installedFirefoxProfileAddonIds["$queriedProfileName $queriedId"]}" ] && return 0

    local firefoxAddonRecord; for firefoxAddonRecord in "${!addedFirefoxAddons[@]}"
    do
	local profileName addonId addonUrl
	IFS=: read -r profileName addonId addonUrl <<<"$firefoxAddonRecord"
	[ -z "$profileName" ] && profileName="${firefoxDefaultProfileName:?}"	# Re-use default profile name cached by hasFirefoxAddon().

	[ "$profileName" = "$queriedProfileName" -a "$addonId" = "$queriedId" ] && return 0
    done

    return 1
}

installFirefoxAddon()
{
    [ ${#addedFirefoxAddons[@]} -gt 0 ] || return

    typeset -A firefoxAddonUrlsByProfile=()
    local firefoxAddonRecord; for firefoxAddonRecord in "${!addedFirefoxAddons[@]}"
    do
	local profileName addonId addonUrl
	IFS=: read -r profileName addonId addonUrl <<<"$firefoxAddonRecord"
	[ -z "$profileName" ] && profileName="${firefoxDefaultProfileName:?}"	# Re-use default profile name cached by hasFirefoxAddon().

	printf -v quotedAddonUrl '%q' "$addonUrl"
	firefoxAddonUrlsByProfile["$profileName"]="${firefoxAddonUrlsByProfile["$profileName"]}${firefoxAddonUrlsByProfile["$profileName"]:+ }${quotedAddonUrl}"
    done

    for profileName in "${!firefoxAddonUrlsByProfile[@]}"
    do
	toBeInstalledCommands+=("firefox -no-remote -P $profileName ${firefoxAddonUrlsByProfile["$profileName"]}")
    done
}

typeRegistry+=([firefox:]=FirefoxAddon)
typeInstallOrder+=([800]=FirefoxAddon)
