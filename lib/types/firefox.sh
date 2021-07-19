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
The browser to be launched (per PROFILE-NAME) can be configured via a
    config:FIREFOX=/opt/firefox/firefox
configuration item following it.
HELPTEXT
}

readonly FIREFOX_PROFILES_DIRSPEC=~/.mozilla/firefox

typeRegistry+=([firefox:]=FirefoxAddon)
typeInstallOrder+=([800]=FirefoxAddon)

if ! exists firefox || ! hasNative firefox; then
    hasFirefoxAddon() { return 98; }
    installFirefoxAddon() { :; }
    isAvailableFirefoxAddon() { return 98; }
    return
fi

typeset -A installedFirefoxProfileAddonIds=()
typeset -A isInstalledFirefoxAddonsAvailable=()
getInstalledFirefoxAddons()
{
    local profileName="${1:?}"; shift
    [ "${isInstalledFirefoxAddonsAvailable["$profileName"]}" ] && return
    local addonsConfigFilespec="${1:?}/addons.json"; shift
    isDependencyAvailableOrUserAcceptsNative jq

    local exitStatus id; while IFS=$'\n' read -r id || { exitStatus="$id"; break; }	# Exit status from the process substitution (<(jq)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedFirefoxProfileAddonIds["$profileName $id"]=t
	case ",${DEBUG:-}," in *,setup-software:firefox,*) echo >&2 "${PS4}setup-software (firefox): Found $id installed in profile $profileName";; esac
    done < <(jq --raw-output '.addons | .[] | .id' "$addonsConfigFilespec"; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledFirefoxAddonsAvailable["$profileName"]=t
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

    if ! getInstalledFirefoxAddons "$profileName" "$configDirspec"; then
	messagePrintf >&2 'ERROR: Failed to obtain Firefox installed add-on list for profile %s; skipping %s.\n' "$profileName" "$1"
	return 99
    fi
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

    typeset -A firefoxExecutableByProfile=()	# Assumption: Each profile is opened by a particular Firefox executable, so a mapping of profile -> executable suffices, and we don't need to store profile and executable as independent vectors.
    typeset -A firefoxAddonUrlsByProfile=()
    local firefoxAddonRecord; for firefoxAddonRecord in "${!addedFirefoxAddons[@]}"
    do
	FIREFOX=
	eval "${configuration["firefox:$firefoxAddonRecord"]}"

	local profileName addonId addonUrl
	IFS=: read -r profileName addonId addonUrl <<<"$firefoxAddonRecord"
	[ -z "$profileName" ] && profileName="${firefoxDefaultProfileName:?}"	# Re-use default profile name cached by hasFirefoxAddon().

	firefoxExecutableByProfile["$profileName"]="${FIREFOX:-firefox}"
	printf -v quotedAddonUrl '%q' "$addonUrl"
	firefoxAddonUrlsByProfile["$profileName"]="${firefoxAddonUrlsByProfile["$profileName"]}${firefoxAddonUrlsByProfile["$profileName"]:+ }${quotedAddonUrl}"
    done

    for profileName in "${!firefoxAddonUrlsByProfile[@]}"
    do
	submitInstallCommand "${firefoxExecutableByProfile["$profileName"]} -no-remote -P $profileName ${firefoxAddonUrlsByProfile["$profileName"]}"
    done
}
