#!/bin/bash source-this-script

configUsageCustom()
{
    cat <<'HELPTEXT'
custom: items consist of a CHECK:ACTION pair, where the latter will be chosen if
the former does not succeed.
CHECK can be one of the following (in decreasing precedence):
- an EXECUTABLE-COMMAND in the ./etc/custom directory tree that is called and
  should succeed if the application already exists, and fail if it is missing;
  if EXECUTABLE-COMMAND starts with a &, this is replaced by the following
  ACTION (without a $SUDO prefix), allowing you to save repeated typing:
	custom:&-check:foo-installer
- an EXECUTABLE-NAME? (located through $PATH) or GLOB?, and succeeds if
  it's there / resolves to an existing file or directory
- the special expression "false"; then, no check is performed and whether the
  installation action will happen depends solely on the (potentially recalled or
  derived from the whole definition) user's answer
- a TEST-EXPRESSION (whitespace must be escaped or the entire expression
  quoted!) that is eval'd and should succeed if the application already
  exists, and fail if it is missing, fail with 98 if this item and with 99 if
  the entire definition should be skipped; if TEST-EXPRESSION starts with a &,
  this is replaced by the following ACTION (without a $SUDO prefix and without
  its command-line arguments), allowing you to re-use the same script for
  checking and installing:
	custom:'& --check':foo-installer
    or save repeated typing:
	custom:&-check:foo-installer
  Note: This cannot contain literal colons, as these would prematurely end the
  TEST-EXPRESSION; you can use $(echo -e \\x3a) instead of : as a workaround.
ACTION is one of the following:
- an executable command (potentially followed by command-line arguments) in the
  ./etc/custom directory tree that is invoked (prepend $SUDO if it needs to be
  invoked as root) and should then install the application
- a text file in the ./etc/custom directory tree whose file name (without
  extension) is taken as a notification title and contents as notification to be
  displayed (presumably with instructions for manual installation steps)
  immediately and on each login until the user acknowledges it
- another ITEM (that is then executed as usual); for packages installed via the
  distribution's package manager, use the special "native:" prefix here
- an INSTALL-EXPRESSION (whitespace must be escaped or the entire expression
  quoted!) that is eval'd (prepend $SUDO if it needs to be invoked as root)
HELPTEXT
}

typeset -A addedCustomActions=()
typeset -a addedCustomActionList=()
hasCustom()
{
    local customAction="${1#*:}"
    local customCheck="${1%":$customAction"}"
    local customActionWithoutSudoAndArgs="${customAction#\$SUDO }"; customActionWithoutSudoAndArgs="${customActionWithoutSudoAndArgs%% *}"

    if [ -z "$customAction" -o -z "$customCheck" ]; then
	printf >&2 'ERROR: Invalid custom item: "custom:%s"\n' "$1"
	exit 3
    fi

    [ "${addedCustomActions["$customAction"]}" ] && return 0	# This custom action has already been selected for installation.

    if [ -x "${customActionsDirspec}/${customCheck}" ]; then
	"${customActionsDirspec}/${customCheck}"
    elif [[ "$customCheck" =~ \?$ ]] && local customCheckLikeAction="${customActionsDirspec}/${customActionWithoutSudoAndArgs}${customCheck#\&}" && [ -x "$customCheckLikeAction" ]; then
	"$customCheckLikeAction"
    elif [[ "$customCheck" =~ \?$ ]]; then
	which "${customCheck%\?}" >/dev/null 2>&1 || expandglob -- "${customCheck%\?}" >/dev/null 2>&1
    else
	if [[ "$customCheck" =~ ^\& ]]; then
	    if [ -x "${customActionsDirspec}/${customActionWithoutSudoAndArgs}" ]; then
		customActionWithoutSudoAndArgs="${customActionsDirspec}/${customActionWithoutSudoAndArgs}"
	    fi
	    customCheck="${customActionWithoutSudoAndArgs}${customCheck#\&}"
	fi

	eval "$customCheck"
    fi
}

typeset -A itemActions=()
addCustom()
{
    # Note: Do not support pre-/postinstall hooks here, as we have no short
    # "name" that we could use.
    local customAction="${1#*:}"
    addedCustomActions["$customAction"]=t
    addedCustomActionList+=("$customAction")

    local customActionWithoutSudo="${customAction#\$SUDO }"
    if [ ! -x "${customActionsDirspec}/${customActionWithoutSudo%% *}" ] && \
	[ ! -e "${customActionsDirspec}/${customAction}" ]; then
	local name="${customAction#*:}"
	local prefix="${customAction%"$name"}"
	# Note: Native packages would be indistinguishable from the
	# INSTALL-EXPRESSION, as they have no prefix, so use a special
	# "native:" prefix.
	if [ -n "$prefix" ]; then
	    local typeFunction="${typeRegistry["${prefix}"]}"
	    if [ -n "$typeFunction" ]; then
		itemActions["$customAction"]=t
		eval "add${typeFunction} \"\$name\""
	    fi
	fi
    fi
}

installCustom()
{
    [ ${#addedCustomActions[@]} -eq ${#addedCustomActionList[@]} ] || { echo >&2 'ASSERT: Invalid whatever'; exit 3; }
    [ ${#addedCustomActionList[@]} -gt 0 ] || return

    local customAction; for customAction in "${addedCustomActionList[@]}"
    do
	local customActionWithoutSudo="${customAction#\$SUDO }"
	local sudoPrefix="${customAction%"$customActionWithoutSudo"}"

	if [ "${itemActions["$customAction"]}" ]; then
	    # The corresponding action item has already been added to the item's
	    # type; do nothing here.
	    continue
	elif [ -x "${customActionsDirspec}/${customActionWithoutSudo%% *}" ]; then
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
