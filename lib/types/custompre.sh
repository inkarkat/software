#!/bin/bash source-this-script

configUsageCustomPre()
{
    cat <<'HELPTEXT'
custompre: items consist of a CHECK:ACTION pair, where the latter will be chosen
if the former does not succeed. It works just like custom:, but is executed
before any other installation action (native or otherwise), but still after any
configuration type.
HELPTEXT
}

typeset -A addedCustomPreActions=()
typeset -a addedCustomPreActionList=()
typeset -A addedCustomPreConfigs=()
hasCustomPre()
{
    local customRecord="${1:?}"; shift
    local customAction="${customRecord#*:}"
    local customCheck="${customRecord%":$customAction"}"
    local customCheckWithoutSudo="${customCheck#\$SUDO }"
    local sudoPrefix="${customCheck%"$customCheckWithoutSudo"}"
    local customActionWithoutSudoAndArgs="${customAction#\$SUDO }"; customActionWithoutSudoAndArgs="${customActionWithoutSudoAndArgs%% *}"

    if [ -z "$customAction" -o -z "$customCheck" ]; then
	printf >&2 'ERROR: Invalid custompre item: "custompre:%s"\n' "$1"
	exit 3
    fi

    [ "${addedCustomPreActions["$customAction"]}" ] && return 0	# This custompre action has already been selected for installation.

    local config="${hasConfiguration["custompre:$customRecord"]}"; config="${config//$'\n'/ }"
    local customFilespec customCheckCommand
    local customDecoration="${decoration["custompre:${customRecord}"]}"
    if [ "$customCheck" = 'once' ]; then
	eval "${config}${config:+ }$(getQuotedCustomOnceMarkerCommand --query "$customAction")"
    elif customFilespec="$(getCustomFilespec -x "${customCheckWithoutSudo}")"; then
	customCheckCommand="${sudoPrefix:+${SUDO}${SUDO:+ }}\"\$customFilespec\""
	invokeCheck "$(decorateCommand "${config}${config:+ }${customCheckCommand}" "$customDecoration")"
    elif [[ "$customCheckWithoutSudo" =~ ^\& ]] && customFilespec="$(getCustomFilespec -x "${customActionWithoutSudoAndArgs}${customCheckWithoutSudo#\&}")"; then
	customCheckCommand="${sudoPrefix:+${SUDO}${SUDO:+ }}\"\$customFilespec\""
	invokeCheck "$(decorateCommand "${config}${config:+ }${customCheckCommand}" "$customDecoration")"
    elif [[ "$customCheck" =~ ^\!.*\?$ ]]; then
	customCheck="${customCheck#\!}"
	! customPathOrGlobCheck "${customCheck%\?}"
    elif [[ "$customCheck" =~ \?$ ]]; then
	customPathOrGlobCheck "${customCheck%\?}"
    else
	if [[ "$customCheckWithoutSudo" =~ ^\& ]]; then
	    if customFilespec="$(getCustomFilespec -x "${customActionWithoutSudoAndArgs}")"; then
		customActionWithoutSudoAndArgs="$customFilespec"
	    fi
	    customCheckWithoutSudo="${customActionWithoutSudoAndArgs}${customCheckWithoutSudo#\&}"
	fi

	if [[ "$customCheckWithoutSudo" =~ '!*' ]]; then
	    local customActionArgs="${customAction#\$SUDO }"; customActionArgs="${customActionArgs#* }"
	    customCheckWithoutSudo="${customCheckWithoutSudo//\!\*/"${customActionArgs}"}"
	fi

	customCheckCommand="${sudoPrefix:+${SUDO}${SUDO:+ }}$customCheckWithoutSudo"
	invokeCheck "$(decorateCommand "${config}${config:+ }${customCheckCommand}" "$customDecoration")"
    fi
}

typeset -A itemCustomPreActions=()
typeset -A onceCustomPreActions=()
addCustomPre()
{
    # Note: Do not support pre-/postinstall hooks here, as we have no short
    # "name" that we could use.
    local customRecord="${1:?}"; shift
    local customAction="${customRecord#*:}"
    local customCheck="${customRecord%":$customAction"}"
    addedCustomPreActions["$customAction"]="$customRecord"
    addedCustomPreActionList+=("$customAction")
    addedCustomPreConfigs["$customAction"]="${configuration["custompre:$customRecord"]}"

    if [ "$customCheck" = 'once' ]; then
	onceCustomPreActions["$customAction"]=t
    fi

    local customActionWithoutSudo="${customAction#\$SUDO }"
    if ! getCustomFilespec -x "${customActionWithoutSudo%% *}" >/dev/null && \
	! getCustomFilespec -e "${customAction}" >/dev/null; then
	local name="${customAction#*:}"
	local prefix="${customAction%"$name"}"
	# Note: Native packages would be indistinguishable from the
	# INSTALL-EXPRESSION, as they have no prefix, so use a special
	# "native:" prefix.
	if [ -n "$prefix" ]; then
	    local typeFunction="${typeRegistry["${prefix}"]}"
	    if [ -n "$typeFunction" ]; then
		itemCustomPreActions["$customAction"]=t
		"add${typeFunction}" "$name"

		if [ "$customCheck" = 'once' ]; then
		    # Synthesize a postinstall: command for ITEM actions that
		    # set the marker for execution.
		    addPostinstall "$(getQuotedCustomOnceMarkerCommand --update "$customAction")"$'\n'"$customAction"
		fi
	    fi
	fi
    fi
}

installCustomPre()
{
    [ ${#addedCustomPreActions[@]} -eq ${#addedCustomPreActionList[@]} ] || { echo >&2 'ASSERT: CustomPre actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedCustomPreActionList[@]} -gt 0 ] || return

    local customAction; for customAction in "${addedCustomPreActionList[@]}"
    do
	local config="${addedCustomPreConfigs["$customAction"]}"; config="${config//$'\n'/ }"
	local customActionWithoutSudo="${customAction#\$SUDO }"
	local customActionWithoutSudoAndArgs="${customActionWithoutSudo%% *}"
	local sudoPrefix="${customAction%"$customActionWithoutSudo"}"
	local customFilespec
	local customRecord="${addedCustomPreActions["$customAction"]}"
	local customDecoration="${decoration["custompre:$customRecord"]}"
	local quotedCustomOnceMarkerCommand=; [ "${onceCustomPreActions["$customAction"]}" ] && quotedCustomOnceMarkerCommand="$(getQuotedCustomOnceMarkerCommand --update "$customAction")"

	if [ "${itemCustomPreActions["$customAction"]}" ]; then
	    # The corresponding action item has already been added to the item's
	    # type; do nothing here.
	    continue
	elif customFilespec="$(getCustomFilespec -x "${customActionWithoutSudoAndArgs}")"; then
	    local customArgs="${customActionWithoutSudo#"$customActionWithoutSudoAndArgs"}"
	    customActionWithoutSudo="${customFilespec}${customArgs}"
	elif customFilespec="$(getCustomFilespec -e "${customAction}")"; then
	    local quotedCustomNotification; printf -v quotedCustomNotification %s "$customFilespec"
	    submitInstallCommand "${config}${config:+ }addLoginNotification --file $quotedCustomNotification --immediate --no-blocking-gui${quotedCustomOnceMarkerCommand:+ && }${quotedCustomOnceMarkerCommand}" "$customDecoration"
	    continue
	fi
	submitInstallCommand "${sudoPrefix:+${SUDO}${config:+ --preserve-env}${SUDO:+ }}${config}${config:+ }${customActionWithoutSudo}${quotedCustomOnceMarkerCommand:+ && }${quotedCustomOnceMarkerCommand}" "$customDecoration"
    done
}

typeRegistry+=([custompre:]=CustomPre)
typeInstallOrder+=([99]=CustomPre)
