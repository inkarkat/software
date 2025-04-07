#!/bin/bash source-this-script

configUsageThunderbirdAddon()
{
    cat <<'HELPTEXT'
thunderbird: items consist of a
    [PROFILE-NAME]:ADDON-ID:ADDON-URL
triplet.
It checks the Thunderbird PROFILE-NAME / default profile for ADDON-ID and if that
isn't installed yet launches ADDON-URL to let you download the latest package
for (manual) installation of the add-on.
HELPTEXT
}

typeRegistry+=([thunderbird:]=ThunderbirdAddon)
typeInstallOrder+=([810]=ThunderbirdAddon)

if ! exists thunderbird \
    || ! THUNDERBIRD_PROFILES_DIRSPEC="$("${projectDir}/lib/getThunderbirdProfileDirspec.sh" 2>/dev/null)" \
    || [ ! -d "$THUNDERBIRD_PROFILES_DIRSPEC" ]
then
    hasThunderbirdAddon() { return 98; }
    installThunderbirdAddon() { :; }
    isAvailableThunderbirdAddon() { return 98; }
    return
fi

typeset -A installedThunderbirdProfileAddonIds=()
typeset -A isInstalledThunderbirdAddonsAvailable=()
getInstalledThunderbirdAddons()
{
    local profileName="${1:?}"; shift
    [ "${isInstalledThunderbirdAddonsAvailable["$profileName"]}" ] && return
    local addonsConfigFilespec="${1:?}/addons.json"; shift
    [ -e "$addonsConfigFilespec" ] || return 0	# Silently skip profile that doesn't have any add-ons installed yet.
    isDependencyAvailableOrUserAcceptsNative jq

    local exitStatus id; while IFS=$'\n' read -r id || { exitStatus="$id"; break; }	# Exit status from the process substitution (<(jq)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedThunderbirdProfileAddonIds["$profileName $id"]=t
	case ",${DEBUG:-}," in *,setup-software:thunderbird,*) echo >&2 "${PS4}setup-software (thunderbird): Found $id installed in profile $profileName";; esac
    done < <(jq --raw-output '.addons | .[] | .id' "$addonsConfigFilespec"; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledThunderbirdAddonsAvailable["$profileName"]=t
}
typeset -A addedThunderbirdAddons=()
hasThunderbirdAddon()
{
    local profileName addonId addonUrl
    IFS=: read -r profileName addonId addonUrl <<<"$1"
    if [ -z "$addonId" -o -z "$addonUrl" ]; then
	printf >&2 'ERROR: Invalid thunderbird item: "thunderbird:%s"\n' "$1"
	exit 3
    fi

    [ "${addedThunderbirdAddons["$1"]}" ] && return 0	# This add-on has already been selected for installation.

    local _disabledNoGlob=
    case $- in
	*f*)    set +f; _disabledNoGlob=t;;
    esac
	if [ -z "$profileName" ]; then
	    typeset -a existingProfileDirspecs=("$THUNDERBIRD_PROFILES_DIRSPEC"/*.default?(-release))
	else
	    typeset -a existingProfileDirspecs=("$THUNDERBIRD_PROFILES_DIRSPEC"/*."$profileName")
	fi
    [ "${_disabledNoGlob:-}" ] && set -f; unset _disabledNoGlob

    local configDirspec="${existingProfileDirspecs[0]}"
    [ -d "$configDirspec" ] || return 99 # No such Thunderbird profile.
    if [ -z "$profileName" ]; then
	profileName="${configDirspec##*.}"
	thunderbirdDefaultProfileName="$profileName"
    fi

    if ! getInstalledThunderbirdAddons "$profileName" "$configDirspec"; then
	messagePrintf >&2 'ERROR: Failed to obtain Thunderbird installed add-on list for profile %s; skipping %s.\n' "$profileName" "$1"
	return 99
    fi
    [ "${installedThunderbirdProfileAddonIds["${profileName} ${addonId}"]}" ]
}

addThunderbirdAddon()
{
    local thunderbirdAddonRecord="${1:?}"; shift
    local addonId="${thunderbirdAddonRecord#*:}"; addonId="${addonId%%:*}"
    exists thunderbird || return $?

    preinstallHook ThunderbirdAddon "$addonId"
    addedThunderbirdAddons["$thunderbirdAddonRecord"]=t
    postinstallHook ThunderbirdAddon "$addonId"
}

isAvailableThunderbirdAddon()
{
    local profileNameAndId="${1:?}"; shift
    local queriedProfileName="${profileNameAndId%%:*}"; shift
    local queriedId="${profileNameAndId#"${queriedProfileName}:"}"; shift

    hasThunderbirdAddon "${queriedProfileName}:dummyId:dummyUrl"	# Obtain the addons for the queried profile.
    [ -z "$queriedProfileName" ] && queriedProfileName="${thunderbirdDefaultProfileName:?}"
    [ "${installedThunderbirdProfileAddonIds["$queriedProfileName $queriedId"]}" ] && return 0

    local thunderbirdAddonRecord; for thunderbirdAddonRecord in "${!addedThunderbirdAddons[@]}"
    do
	local profileName addonId addonUrl
	IFS=: read -r profileName addonId addonUrl <<<"$thunderbirdAddonRecord"
	[ -z "$profileName" ] && profileName="${thunderbirdDefaultProfileName:?}"	# Re-use default profile name cached by hasThunderbirdAddon().

	[ "$profileName" = "$queriedProfileName" -a "$addonId" = "$queriedId" ] && return 0
    done

    return 1
}

installThunderbirdAddon()
{
    [ ${#addedThunderbirdAddons[@]} -gt 0 ] || return

    typeset -A thunderbirdAddonUrlsByProfile=()
    local thunderbirdAddonRecord; for thunderbirdAddonRecord in "${!addedThunderbirdAddons[@]}"
    do
	local profileName addonId addonUrl
	IFS=: read -r profileName addonId addonUrl <<<"$thunderbirdAddonRecord"
	[ -z "$profileName" ] && profileName="${thunderbirdDefaultProfileName:?}"	# Re-use default profile name cached by hasThunderbirdAddon().

	printf -v quotedAddonUrl '%q' "$addonUrl"
	thunderbirdAddonUrlsByProfile["$profileName"]="${thunderbirdAddonUrlsByProfile["$profileName"]}${thunderbirdAddonUrlsByProfile["$profileName"]:+ }${quotedAddonUrl}"
    done

    for profileName in "${!thunderbirdAddonUrlsByProfile[@]}"
    do
	profileComment=" # for the $profileName profile"; [ "$profileName" = "$thunderbirdDefaultProfileName" ] && profileComment=''
	submitInstallCommand "browse ${thunderbirdAddonUrlsByProfile["$profileName"]}${profileComment}"
    done
}
