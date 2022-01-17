#!/bin/bash source-this-script

configUsageNotifyUrl()
{
    : ${INSTALL_REPO:=~/install}
    cat <<HELPTEXT
notify+url: items consist of a
    [MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]FILE-GLOB:[URL [...]]
triplet.
If ${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/FILE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the
notification file from URL(s) (first that succeeds) will be downloaded (and put
into ${INSTALL_REPO}/* if it exists).
If no URL is given and the notification file does not exist, the installation
will fail.
HELPTEXT
}

typeset -A addedNotifyUrlRecords=()
hasNotifyUrl()
{
    [ "${addedNotifyUrlRecords["${1:?}"]}" ] && return 0	# This notification file has already been selected for installation.

    return 1	# We cannot easily check for the notification file without downloading it. This item is meant to be used as a postinstall item, triggered by the installation of the main package, anyway.
}

addNotifyUrl()
{
    local notifyUrlRecord="${1:?}"; shift
    addedNotifyUrlRecords["$notifyUrlRecord"]=t
}

installNotifyUrl()
{
    [ ${#addedNotifyUrlRecords[@]} -gt 0 ] || return
    local notifyUrlRecord; for notifyUrlRecord in "${!addedNotifyUrlRecords[@]}"
    do
	local maxAge notificationNameAndGlob notificationUrlList
	IFS=: read -r maxAge notificationNameAndGlob notificationUrlList <<<"$notifyUrlRecord"
	local notificationGlob="${notificationNameAndGlob##*/}"
	local notificationName="${notificationNameAndGlob%"$notificationGlob"}"
	if [ -z "$notificationGlob" ]; then
	    printf >&2 'ERROR: Invalid notify+url item: "notify+url:%s"\n' "$notifyUrlRecord"
	    exit 3
	fi
	local notificationOutputNameArg=; isglob "$notificationGlob" || printf -v notificationOutputNameArg %q "$notificationGlob"
	printf -v notificationGlob %q "$notificationGlob"
	notificationName="${notificationName%/}"
	printf -v notificationName %q "$notificationName"
	typeset -a notificationUrls=(); IFS=' ' read -r -a notificationUrls <<<"$notificationUrlList"
	local notificationUrlArgs=''; [ ${#notificationUrls[@]} -gt 0 ] && printf -v notificationUrlArgs ' --url %q' "${notificationUrls[@]}"

	# Note: No sudo here, as the downloading will happen as the current user
	# and only the installation itself will be done through sudo.
	submitInstallCommand \
	    "login-notification-download${isBatch:+ --batch} --immediate --no-blocking-gui${notificationName:+ --application-name }${notificationName} --expression ${notificationGlob}${maxAge:+ --max-age }$maxAge${notificationUrlArgs}${notificationOutputNameArg:+ --output }${notificationOutputNameArg}" \
	    "${decoration["notify+url:$notifyUrlRecord"]}"
    done
}

typeRegistry+=([notify+url:]=NotifyUrl)
typeInstallOrder+=([900]=NotifyUrl)
