#!/bin/bash source-this-script

configUsageCustomAtOrder()
{
    local order="${1?}"; shift
    local when="${1:?}"; shift
    cat <<HELPTEXT
custom${order}: items consist of a CHECK:ACTION pair, where the latter will be chosen if
the former does not succeed.
CHECK can be one of the following (in decreasing precedence):
- an EXECUTABLE-COMMAND in the ./etc/custom directory tree that is called and
  should succeed if the application already exists, and fail if it is missing;
  if EXECUTABLE-COMMAND starts with a &, this is replaced by the following
  ACTION (without a \$SUDO prefix), allowing you to save repeated typing:
	custom${order}:&-check:foo-installer
  (Prepend \$SUDO if the command needs to be invoked as root; but try your best
  to avoid that.)
- an EXECUTABLE-NAME? (located through \$PATH) or GLOB? (potentially prefixed
  with !), and succeeds if it's (with !: not) there / resolves to an existing
  file, directory, or symlink
- the special expression "once"; then, no check is performed and the
  installation action (if chosen by the user) will happen only once
- a TEST-EXPRESSION (whitespace must be escaped or the entire expression
  quoted!) that is eval'd and should succeed if the application already
  exists, and fail if it is missing, fail with 98 if this item and with 99 if
  the entire definition should be skipped; if TEST-EXPRESSION starts with a &,
  this is replaced by the following ACTION (without a \$SUDO prefix and without
  its command-line arguments); !* is replaced with any arguments given to
  ACTION, allowing you to re-use the same script for checking and installing:
	custom${order}:'& --check !* --quiet':foo-installer --recursive
  Note: This cannot contain literal colons, as these would prematurely end the
  TEST-EXPRESSION; you can use \$(echo -e \\\\x3a) instead of : as a workaround.
  (Prepend \$SUDO if the expression needs to be invoked as root; but try your
  best to avoid that.)
ACTION $when and is one of the following:
- an EXECUTABLE-COMMAND (potentially followed by command-line arguments) in the
  ./etc/custom directory tree that is invoked (prepend \$SUDO if it needs to be
  invoked as root) and should then install the application
- a TEXT-FILE in the ./etc/custom directory tree whose file name (without
  extension) is taken as a notification title and contents as notification to be
  displayed (presumably with instructions for manual installation steps)
  immediately and on each login until the user acknowledges it
- another ITEM (that is then executed as usual); for packages installed via the
  distribution's package manager, use the special "native:" prefix here
- an INSTALL-EXPRESSION (whitespace must be escaped or the entire expression
  quoted!) that is eval'd (prepend \$SUDO if it needs to be invoked as root)
Environment variables for the check and custom action can be passed via
    config:VAR=NAME
configuration item(s) preceding it.
HELPTEXT
}
configUsageCustomPre()
{
    configUsageCustomAtOrder 'pre' $'is executed before any other installation action (native or otherwise),\nbut still after any configuration type' "$@"
}
configUsageCustom()
{
    configUsageCustomAtOrder '' 'is executed at the very end of the installation' "$@"
}

customPathOrGlobCheck()
{
    local executableNameOrGlob="${1:?}"; shift
    which "$executableNameOrGlob" >/dev/null 2>&1 || \
	expandglob -- "$executableNameOrGlob" >/dev/null 2>&1
}

getCustomFilespec()
{
    local compareOp="${1:?}"; shift
    local customAction="${1?}"; shift
    [ -n "$customAction" ] || return 1

    local dirspec; for dirspec in "${additionalBaseDirs[@]}" "$baseDir"
    do
	local customFilespec="${dirspec}/custom/${customAction}"
	if [ $compareOp "$customFilespec" ]; then
	    printf %s "$customFilespec"
	    return 0
	fi
    done
    return 1
}

getQuotedCustomOnceMarkerCommand()
{
    printf '%q ' executionMarker --base-type data --namespace "$setupName" --group custom-once "$@"
}

typeset -A addedCustomPreActions=()
typeset -a addedCustomPreActionList=()
typeset -A addedCustomPreConfigs=()
typeset -A addedCustomActions=()
typeset -a addedCustomActionList=()
typeset -A addedCustomConfigs=()
hasCustomAtOrder()
{
    local order="${1?}"; shift
    local customRecord="${1:?}"; shift
    local customAction="${customRecord#*:}"
    local customCheck="${customRecord%":$customAction"}"
    local customCheckWithoutSudo="${customCheck#\$SUDO }"
    local sudoPrefix="${customCheck%"$customCheckWithoutSudo"}"
    local customActionWithoutSudoAndArgs="${customAction#\$SUDO }"; customActionWithoutSudoAndArgs="${customActionWithoutSudoAndArgs%% *}"

    if [ -z "$customAction" -o -z "$customCheck" ]; then
	printf >&2 'ERROR: Invalid custom item: "custom%s:%s"\n' "$order" "$1"
	exit 3
    fi

    eval "[ \"\${addedCustom${order^}Actions[\"\$customAction\"]}\" ]" && return 0	# This custom action has already been selected for installation.

    local config="${hasConfiguration["custom${order}:${customRecord}"]}"; config="${config//$'\n'/ }"
    local customFilespec customCheckCommand
    local customDecoration="${decoration["custom${order}:${customRecord}"]}"
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
hasCustomPre()
{
    hasCustomAtOrder 'pre' "$@"
}
hasCustom()
{
    hasCustomAtOrder '' "$@"
}

typeset -A itemCustomPreActions=()
typeset -A onceCustomPreActions=()
typeset -A itemCustomActions=()
typeset -A onceCustomActions=()
addCustomAtOrder()
{
    local order="${1?}"; shift
    # Note: Do not support pre-/postinstall hooks here, as we have no short
    # "name" that we could use.
    local customRecord="${1:?}"; shift
    local customAction="${customRecord#*:}"
    local customCheck="${customRecord%":$customAction"}"
    eval "addedCustom${order^}Actions[\"\$customAction\"]=\"\$customRecord\""
    eval "addedCustom${order^}ActionList+=(\"\$customAction\")"
    eval "addedCustom${order^}Configs[\"\$customAction\"]=\"\${configuration[\"custom${order}:\${customRecord}\"]}\""

    if [ "$customCheck" = 'once' ]; then
	eval "onceCustom${order^}Actions[\"\$customAction\"]=t"
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
		eval "itemCustom${order^}Actions[\"\$customAction\"]=t"
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
addCustomPre()
{
    addCustomAtOrder 'pre' "$@"
}
addCustom()
{
    addCustomAtOrder '' "$@"
}

installCustomAtOrder()
{
    local order="${1?}"; shift
    eval "[ \${#addedCustom${order^}Actions[@]} -eq \${#addedCustom${order^}ActionList[@]} ]" || { echo >&2 'ASSERT: Custom actions dict and list sizes disagree.'; exit 3; }
    eval "[ \${#addedCustom${order^}ActionList[@]} -gt 0 ]" || return

    local -n actionList=addedCustom${order^}ActionList
    local -n configs=addedCustom${order^}Configs
    local -n actions=addedCustom${order^}Actions
    local customAction; for customAction in "${actionList[@]}"
    do
	local config="${configs["$customAction"]}"; config="${config//$'\n'/ }"
	local customActionWithoutSudo="${customAction#\$SUDO }"
	local customActionWithoutSudoAndArgs="${customActionWithoutSudo%% *}"
	local sudoPrefix="${customAction%"$customActionWithoutSudo"}"
	local customFilespec
	local customRecord="${actions["$customAction"]}"
	local customDecoration="${decoration["custom${order}:${customRecord}"]}"
	local quotedCustomOnceMarkerCommand=; eval "[ \"\${onceCustom${order^}Actions[\"\$customAction\"]}\" ]" && quotedCustomOnceMarkerCommand="$(getQuotedCustomOnceMarkerCommand --update "$customAction")"

	eval "local hasItemCustomAction=\${itemCustom${order^}Actions[\"\$customAction\"]}"
	if [ "$hasItemCustomAction" ]; then
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
installCustomPre()
{
    installCustomAtOrder 'pre' "$@"
}
installCustom()
{
    installCustomAtOrder '' "$@"
}

typeRegistry+=([custompre:]=CustomPre)
typeRegistry+=([custom:]=Custom)
typeInstallOrder+=([99]=CustomPre)
typeInstallOrder+=([1000]=Custom)
