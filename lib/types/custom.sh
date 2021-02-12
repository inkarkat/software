#!/bin/bash source-this-script

hasCustom()
{
    local customAction="${1#*:}"
    local customCheck="${1%:$customAction}"
    local customActionWithoutSudo="${customAction#\$SUDO }"

    if [ -z "$customAction" -o -z "$customCheck" ]; then
	printf >&2 'ERROR: Invalid custom item: "custom:%s"\n' "$1"
	exit 3
    fi

    if [ -x "${customActionsDirspec}/${customCheck}" ]; then
	"${customActionsDirspec}/${customCheck}"
    elif [[ "$customCheck" =~ \?$ ]] && local customCheckLikeAction="${customActionsDirspec}/${customActionWithoutSudo}${customCheck#\&}" && [ -x "$customCheckLikeAction" ]; then
	"$customCheckLikeAction"
    elif [[ "$customCheck" =~ \?$ ]]; then
	which "${customCheck%\?}" >/dev/null 2>&1 || expandglob -- "${customCheck%\?}" >/dev/null 2>&1
    else
	if [[ "$customCheck" =~ ^\& ]]; then
	    if [ -x "${customActionsDirspec}/${customActionWithoutSudo}" ]; then
		customActionWithoutSudo="${customActionsDirspec}/${customActionWithoutSudo}"
	    fi
	    customCheck="${customActionWithoutSudo}${customCheck#\&}"
	fi

	eval "$customCheck"
    fi
}

typeset -a addedCustomActions=()
addCustom()
{
    addedCustomActions+=("${1#*:}")
}

installCustom()
{
    [ ${#addedCustomActions[@]} -gt 0 ] || return

    local customAction; for customAction in "${addedCustomActions[@]}"
    do
	local customActionWithoutSudo="${customAction#\$SUDO }"
	local sudoPrefix="${customAction%"$customActionWithoutSudo"}"

	if [ -x "${customActionsDirspec}/${customActionWithoutSudo}" ]; then
	    customActionWithoutSudo="${customActionsDirspec}/${customActionWithoutSudo}"
	elif [ -e "${customActionsDirspec}/${customAction}" ]; then
	    local quotedCustomNotification; printf -v quotedCustomNotification %s "${customActionsDirspec}/${customAction}"
	    toBeInstalledCommands+=("addLoginNotification --file $quotedCustomNotification --immediate")
	    continue
	fi
	toBeInstalledCommands+=("${sudoPrefix:+${SUDO}${SUDO:+ }}${customActionWithoutSudo}")
    done
}

typeRegistry+=([custom:]=Custom)
typeInstallOrder+=([1000]=Custom)
