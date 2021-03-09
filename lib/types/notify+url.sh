#!/bin/bash source-this-script

configUsageNotifyUrl()
{
    : ${INSTALL_DIR:=~/install}
    cat <<HELPTEXT
notify+url: items consist of a
    [MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]FILE-GLOB:[URL]
triplet.
If ${INSTALL_DIR}/(SUBDIR|*)/(NAME|*)/FILE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the
notification file from URL will be downloaded (and put into ${INSTALL_DIR}/*
if it exists).
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
	local maxAge notificationNameAndGlob notificationUrl
	IFS=: read -r maxAge notificationNameAndGlob notificationUrl <<<"$notifyUrlRecord"
	local notificationGlob="${notificationNameAndGlob##*/}"
	local notificationName="${notificationNameAndGlob%"$notificationGlob"}"
	if [ -z "$notificationGlob" ]; then
	    printf >&2 'ERROR: Invalid notify+url item: "notify+url:%s"\n' "$notifyUrlRecord"
	    exit 3
	fi
	notificationName="${notificationName%/}"

	# Note: No sudo here, as the downloading will happen as the current user
	# and only the installation itself will be done through sudo.
	toBeInstalledCommands+=("login-notification-download --immediate --no-blocking-gui${notificationName:+ --application-name "'"}${notificationName}${notificationName:+"'"} --expression '$notificationGlob'${maxAge:+ --max-age }$maxAge --url '$notificationUrl'")
    done
}

typeRegistry+=([notify+url:]=NotifyUrl)
typeInstallOrder+=([900]=NotifyUrl)
