#!/bin/bash source-this-script

configUsageAppImageUrl()
{
    : ${INSTALL_REPO:=~/install}
    cat <<HELPTEXT
appimage+url: items consist of
    [MAX-AGE[SUFFIX]:][[SUBDIR/]NAME/]FILE-GLOB:[URL [...]] [DEST-FILENAME]
If ${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/FILE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, URL(s)
(first that succeeds) will be downloaded (and put into
${INSTALL_REPO}/* if it exists) and copied over to DEST-FILENAME (in
/usr/local/bin, defaulting to the FILE-GLOB without an *.AppImage extension).
HELPTEXT
}

parseAppImageUrl()
{
    typeset -a installArgs=(--sudo --preserve-timestamps)
    local appimageUrlItem="${1:?}"; shift
    eval "set -- $appimageUrlItem"

    local maxAge=
    local applicationNameFileGlobUrl="${1:?}"; shift
    if [[ "$applicationNameFileGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	maxAge="${BASH_REMATCH[0]%:}"
	applicationNameFileGlobUrl="${applicationNameFileGlobUrl#"${BASH_REMATCH[0]}"}"
    fi
    local firstUrl="${applicationNameFileGlobUrl#*:}"
    local applicationNameAndFileGlob="${applicationNameFileGlobUrl%:$firstUrl}"
    local fileGlob="${applicationNameAndFileGlob##*/}"
    local applicationName="${applicationNameAndFileGlob%"$fileGlob"}"
    local outputNameArg=; isglob "$fileGlob" || printf -v outputNameArg %q "$fileGlob"
    printf -v fileGlob %q "$fileGlob"
    applicationName="${applicationName%/}"
    printf -v applicationName %q "$applicationName"
    typeset -a urls=()
    [ -n "$firstUrl" ] && urls+=("$firstUrl")

    local destinationName
    if [[ "${!#}" =~ / ]]; then
	if isglob "$fileGlob"; then
	    printf >&2 'ERROR: Invalid appimage+url item; a real FILE-GLOB needs a DEST-FILENAME: "appimage+url:%s"\n' "$appimageUrlItem"
	    exit 3
	else
	    destinationName="${fileGlob%.AppImage}"
	fi
    else
	destinationName="${!#}"
	set -- "${@:1:$(($#-1))}"
    fi
    local destination="/usr/local/bin/${destinationName:?}"

    urls+=("$@")
    local urlArgs; [ ${#urls[@]} -gt 0 ] && printf -v urlArgs ' --url %q' "${urls[@]}"
    local quotedInstallArgs; [ ${#installArgs[@]} -gt 0 ] && printf -v quotedInstallArgs ' %q' "${installArgs[@]}"

    printf '%s -- %q\n' "file-download-installer${isBatch:+ --batch}${applicationName:+ --application-name }${applicationName} --expression ${fileGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}${quotedInstallArgs}" "$destination"
    printf '%s\n' "$destination"
}

typeset -A addedAppImageUrlActions=()
typeset -a addedAppImageUrlActionList=()
hasAppImageUrl()
{
    if [[ ! "$1" =~ ^[^:]+: ]]; then
	printf >&2 'ERROR: Invalid appimage+url item: "appimage+url:%s"\n' "$1"
	exit 3
    fi
    local parse; parse="$(parseAppImageUrl "${1:?}")" || exit 3
    local fileDownloadInstallerCommand="${parse%%$'\n'*}"
    local destination="${parse#*$'\n'}"

    [ "${addedAppImageUrlActions["$fileDownloadInstallerCommand"]}" ] && return 0	# This appimage+url action has already been selected for installation.

    [ -x "$destination" ]
}

addAppImageUrl()
{
    local appimageUrlRecord="${1:?}"
    local parse; parse="$(parseAppImageUrl "$appimageUrlRecord")" || exit 3
    local fileDownloadInstallerCommand="${parse%%$'\n'*}"
    local destination="${parse#*$'\n'}"
    local destinationName="$(basename -- "$destination")"

    preinstallHook "$destinationName"
    addedAppImageUrlActions["$fileDownloadInstallerCommand"]="$appimageUrlRecord"
    postinstallHook "$destinationName"

    addedAppImageUrlActionList+=("$fileDownloadInstallerCommand")
}

isAvailableAppImageUrl()
{
    isQuiet=t hasAppImageUrl "$@"
}

installAppImageUrl()
{
    [ ${#addedAppImageUrlActions[@]} -eq ${#addedAppImageUrlActionList[@]} ] || { echo >&2 'ASSERT: AppImageUrl actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedAppImageUrlActionList[@]} -gt 0 ] || return

    local appimageUrlAction; for appimageUrlAction in "${addedAppImageUrlActionList[@]}"
    do
	submitInstallCommand "$appimageUrlAction" "${decoration["appimage+url:${addedAppImageUrlActions["$appimageUrlAction"]}"]}"
    done
}

typeRegistry+=([appimage+url:]=AppImageUrl)
typeInstallOrder+=([896]=AppImageUrl)
