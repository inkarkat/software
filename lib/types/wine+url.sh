#!/bin/bash source-this-script

hasWine()
{
    if [[ ! "$1" =~ ^[^:]+\?:.+: ]]; then
	printf >&2 'ERROR: Invalid wine+url item: "wine+url:%s"\n' "$1"
	exit 3
    fi
    local checkGlob="${1%%:*}"

    local -r wineDriveC=~/.wine/drive_c
    if [[ ! "$checkGlob" =~ ^/ ]] && [ -d "$wineDriveC" ]; then
	which "${wineDriveC}/${checkGlob%\?}" >/dev/null 2>&1 || expandglob -- "${wineDriveC}/${checkGlob%\?}" >/dev/null 2>&1 && return 0
    fi
    which "${checkGlob%\?}" >/dev/null 2>&1 || expandglob -- "${checkGlob%\?}" >/dev/null 2>&1
}

typeset -a addedWineUrlPackages=()
addWine()
{
    isAvailable wine && addedWineUrlPackages+=("${1:?}")
}

installWine()
{
    [ ${#addedWineUrlPackages[@]} -gt 0 ] || return
    local wineUrlRecord; for wineUrlRecord in "${addedWineUrlPackages[@]}"
    do
	local maxAge=
	local packageNameGlobUrl="${wineUrlRecord#*:}"
	if [[ "$packageNameGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	    maxAge="${BASH_REMATCH[0]%:}"
	    packageNameGlobUrl="${packageNameGlobUrl#"${BASH_REMATCH[0]}"}"
	fi
	local packageUrl="${packageNameGlobUrl#*:}"
	local packageNameAndGlob="${packageNameGlobUrl%:$packageUrl}"
	local packageGlob="${packageNameAndGlob##*/}"
	local packageName="${packageNameAndGlob%"$packageGlob"}"
	packageName="${packageName%/}"

	# Note: No sudo here, as downloading and installation will happen as the
	# current user.
	toBeInstalledCommands+=("wine-download-installer${packageName:+ --application-name "'"}${packageName}${packageName:+"'"} --expression '$packageGlob'${maxAge:+ --max-age }$maxAge --url '$packageUrl'")
    done
}

typeRegistry+=([wine+url:]=Wine)
typeInstallOrder+=([400]=Wine)
