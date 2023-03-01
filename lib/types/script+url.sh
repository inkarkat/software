#!/bin/bash source-this-script

configUsageScriptUrl()
{
    cat <<'HELPTEXT'
script+url: items consist of
    CHECK:[$SUDO:][MAX-AGE[SUFFIX]:][[SUBDIR/]NAME/]FILE-GLOB:[URL [...]]
If CHECK does not succeed, if${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/FILE-GLOB
already exists [and if it is younger than MAX-AGE[SUFFIX]], it will be used;
else, URL(s) (first that succeeds) will be downloaded (and put into
${INSTALL_REPO}/* if it exists) and installed by interpreting it with the shell
(through sudo if $SUDO: is prepended).
CHECK can be one of the following (in decreasing precedence):
- an EXECUTABLE-COMMAND in the ./etc/custom directory tree that is called and
  should succeed if the application already exists, and fail if it is missing.
  (Prepend $SUDO if the command needs to be invoked as root; but try your best
  to avoid that.)
- an EXECUTABLE-NAME? (located through $PATH) or GLOB? (potentially prefixed
  with !), and succeeds if it's (with !: not) there / resolves to an existing
  file, directory, or symlink
- the special expression "false"; then, no check is performed and whether the
  installation action will happen depends solely on the (potentially recalled or
  derived from the whole definition) user's answer
- a TEST-EXPRESSION (whitespace must be escaped or the entire expression
  quoted!) that is eval'd and should succeed if the application already
  exists, and fail if it is missing, fail with 98 if this item and with 99 if
  the entire definition should be skipped.
  Note: This cannot contain literal colons, as these would prematurely end the
  TEST-EXPRESSION; you can use $(echo -e \\x3a) instead of : as a workaround.
  (Prepend $SUDO if the expression needs to be invoked as root; but try your
  best to avoid that.)
HELPTEXT
}

typeset -A addedScriptUrlActions=()
typeset -a addedScriptUrlActionList=()
hasScriptUrl()
{
    local scriptUrlRecord="${1:?}"; shift
    local scriptUrlAction="${scriptUrlRecord#*:}"
    local scriptUrlCheck="${scriptUrlRecord%":$scriptUrlAction"}"
    local scriptUrlCheckWithoutSudo="${scriptUrlCheck#\$SUDO }"
    local sudoPrefix="${scriptUrlCheck%"$scriptUrlCheckWithoutSudo"}"

    if [ -z "$scriptUrlAction" -o -z "$scriptUrlCheck" ]; then
	printf >&2 'ERROR: Invalid script+url item: "script+url:%s"\n' "$1"
	exit 3
    fi

    [ "${addedScriptUrlActions["$scriptUrlAction"]}" ] && return 0	# This script+url action has already been selected for installation.

    local scriptUrlFilespec scriptUrlCheckCommand
    local scriptUrlDecoration="${decoration["script+url:${scriptUrlRecord}"]}"
    if scriptUrlFilespec="$(getCustomFilespec -x "${scriptUrlCheckWithoutSudo}")"; then
	scriptUrlCheckCommand="${sudoPrefix:+${SUDO}${SUDO:+ }}\"\$scriptUrlFilespec\""
	invokeCheck "$(decorateCommand "$scriptUrlCheckCommand" "$scriptUrlDecoration")"
    elif [[ "$scriptUrlCheckWithoutSudo" =~ ^\& ]] && scriptUrlFilespec="$(getCustomFilespec -x "${scriptUrlActionWithoutSudoAndArgs}${scriptUrlCheckWithoutSudo#\&}")"; then
	scriptUrlCheckCommand="${sudoPrefix:+${SUDO}${SUDO:+ }}\"\$scriptUrlFilespec\""
	invokeCheck "$(decorateCommand "$scriptUrlCheckCommand" "$scriptUrlDecoration")"
    elif [[ "$scriptUrlCheck" =~ ^\!.*\?$ ]]; then
	scriptUrlCheck="${scriptUrlCheck#\!}"
	! customPathOrGlobCheck "${scriptUrlCheck%\?}"
    elif [[ "$scriptUrlCheck" =~ \?$ ]]; then
	customPathOrGlobCheck "${scriptUrlCheck%\?}"
    else
	scriptUrlCheckCommand="${sudoPrefix:+${SUDO}${SUDO:+ }}$scriptUrlCheckWithoutSudo"
	invokeCheck "$(decorateCommand "$scriptUrlCheckCommand" "$scriptUrlDecoration")"
    fi
}

addScriptUrl()
{
    # Note: Do not support pre-/postinstall hooks here, as we have no short
    # "name" that we could use.
    local scriptUrlRecord="${1:?}"; shift
    local scriptUrlAction="${scriptUrlRecord#*:}"
    addedScriptUrlActions["$scriptUrlAction"]="$scriptUrlRecord"
    addedScriptUrlActionList+=("$scriptUrlAction")
}

installScriptUrl()
{
    [ ${#addedScriptUrlActions[@]} -eq ${#addedScriptUrlActionList[@]} ] || { echo >&2 'ASSERT: ScriptUrl actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedScriptUrlActionList[@]} -gt 0 ] || return

    local scriptUrlAction; for scriptUrlAction in "${addedScriptUrlActionList[@]}"
    do
	local sudoArg=; if [[ "$scriptUrlAction" =~ ^\$SUDO:(.*) ]]; then
	    sudoArg='--sudo'
	    scriptUrlAction="${BASH_REMATCH[1]}"
	fi
	local maxAge=
	local applicationNamePackageGlobUrl="${scriptUrlAction#*:}"
	if [[ "$applicationNamePackageGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	    maxAge="${BASH_REMATCH[0]%:}"
	    applicationNamePackageGlobUrl="${applicationNamePackageGlobUrl#"${BASH_REMATCH[0]}"}"
	fi
	local urlList="${applicationNamePackageGlobUrl#*:}"
	local applicationNameAndPackageGlob="${applicationNamePackageGlobUrl%:$urlList}"
	local packageGlob="${applicationNameAndPackageGlob##*/}"
	local applicationName="${applicationNameAndPackageGlob%"$packageGlob"}"
	local outputNameArg=; isglob "$packageGlob" || printf -v outputNameArg %q "$packageGlob"
	printf -v packageGlob %q "$packageGlob"
	applicationName="${applicationName%/}"
	printf -v applicationName %q "$applicationName"
	typeset -a urls=(); IFS=' ' read -r -a urls <<<"$urlList"
	local urlArgs=''; [ ${#urls[@]} -gt 0 ] && printf -v urlArgs ' --url %q' "${urls[@]}"

	# Note: No sudo here, as the downloading will happen as the current user
	# and only the installation itself will be done through sudo.
	submitInstallCommand \
	    "script-download-installer${sudoArg:+ }${sudoArg}${isBatch:+ --batch}${applicationName:+ --application-name }${applicationName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}" \
	    "${decoration["script+url:$scriptUrlAction"]}"
    done
}

typeRegistry+=([script+url:]=ScriptUrl)
typeInstallOrder+=([899]=ScriptUrl)
