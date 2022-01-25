#!/bin/bash source-this-script

printSyntaxRequire()
{
    cat <<'HELPTEXT'
- another ITEM (in abbreviated form, usually just having one "package name"
  parameter); for packages installed via the distribution's package manager, use
  the special "native:" prefix here. The check passes if that ITEM has already
  been installed or has already been selected by the user in the current
  session.
- an EXECUTABLE-COMMAND (potentially prefixed with ! (which negates the status,
  just as in the shell) and/or followed by command-line arguments) in the
  ./etc/require directory tree that is invoked and should fail if the
  requirements are not fulfilled.
  (Prepend $SUDO (before the !) if the command needs to be invoked as root; but
  try your best to avoid that.)
- an EXECUTABLE-NAME? (located through $PATH) or GLOB? (potentially prefixed
  with !), which fulfills the requirement if it's (with !: not) there / resolves
  to an existing file or directory.
- a REQUIREMENT-EXPRESSION (whitespace must be escaped or the entire expression
  quoted!) that is eval'd and should fail if the requirements are not fulfilled.
  (Prepend $SUDO if the expression needs to be invoked as root; but try your
  best to avoid that.)
HELPTEXT
}
configUsageRequire()
{
    echo 'require: items consist of a CHECK that can be:'
    printSyntaxRequire
    cat <<'HELPTEXT'
If the CHECK fails, the entire definition (both preceding and following items)
will be skipped.
HELPTEXT
}
configUsageGroupRequire()
{
    echo 'group-require: items consist of a CHECK that can be:'
    printSyntaxRequire
    cat <<'HELPTEXT'
If the CHECK fails, the entire remainder of the definition group (i.e. the
remaining lines in the file) will be skipped.
HELPTEXT
}

requirePathOrGlobCheck()
{
    local executableNameOrGlob="${1:?}"; shift
    which "$executableNameOrGlob" >/dev/null 2>&1 || \
	expandglob -- "$executableNameOrGlob" >/dev/null 2>&1
}

getQuotedRequirementExecutable()
{
    local requirement="${1?}"; shift
    [ -n "$requirement" ] || return 1

    local dirspec; for dirspec in "${additionalBaseDirs[@]}" "$baseDir"
    do
	local requirementFilespec="${dirspec}/require/${requirement}"
	if [ -x "$requirementFilespec" ]; then
	    printf %q "$requirementFilespec"
	    return 0
	fi
    done
    return 1
}

isDefinitionAcceptedByRequire()
{
    local requirement="${1:?}"; shift
    local definition="${1:?}"; shift

    local name="${requirement#*:}"
    local prefix="${requirement%"$name"}"
    local typeFunction=; [ -n "$prefix" ] && typeFunction="${typeRegistry["$prefix"]}"
    if [ -n "$typeFunction" ]; then
	local availabilityFunctionName="isAvailable${typeFunction}"
	if type -t "$availabilityFunctionName" >/dev/null; then
	    if ! "$availabilityFunctionName" "$name"; then
		[ "$isVerbose" ] && messagePrintf 'Skipping because requirement %s is not passed: %s\n' "$requirement" "$definition"
		return 1
	    fi
	else
	    printf >&2 'ERROR: Type %s cannot be used for requirements checking.\n' "$prefix"
	    exit 3
	fi
    elif [[ "$prefix" =~ ^[^[:space:]]+$ ]]; then
	printf >&2 'ERROR: Invalid type: %s\n' "$prefix"
	exit 3
    else
	local requirementWithoutSudo="${requirement#\$SUDO }"
	local sudoPrefix="${requirement%"$requirementWithoutSudo"}"
	local quotedRequirementFilespec requirementWithoutSudoAndArgs="${requirement%% *}"
	if ! if quotedRequirementFilespec="$(getQuotedRequirementExecutable "$requirementWithoutSudo")"; then
	    invokeCheck "${sudoPrefix:+${SUDO}${SUDO:+ }}$quotedRequirementFilespec"
	elif quotedRequirementFilespec="$(getQuotedRequirementExecutable "${requirementWithoutSudo#!}")"; then
	    invokeCheck "${sudoPrefix:+${SUDO}${SUDO:+ }}! $quotedRequirementFilespec"
	elif quotedRequirementFilespec="$(getQuotedRequirementExecutable "${requirementWithoutSudoAndArgs}")"; then
	    requirementArgs="${requirementWithoutSudo#"${requirementWithoutSudoAndArgs} "}"
	    invokeCheck "${sudoPrefix:+${SUDO}${SUDO:+ }}$quotedRequirementFilespec $requirementArgs"
	elif quotedRequirementFilespec="$(getQuotedRequirementExecutable "${requirementWithoutSudoAndArgs#!}")"; then
	    requirementArgs="${requirementWithoutSudo#"${requirementWithoutSudoAndArgs} "}"
	    invokeCheck "${sudoPrefix:+${SUDO}${SUDO:+ }}! $quotedRequirementFilespec $requirementArgs"
	elif [[ "$requirement" =~ ^\!.*\?$ ]]; then
	    requirement="${requirement#\!}"
	    ! requirePathOrGlobCheck "${requirement%\?}"
	elif [[ "$requirement" =~ \?$ ]]; then
	    requirePathOrGlobCheck "${requirement%\?}"
	else
	    invokeCheck "${sudoPrefix:+${SUDO}${SUDO:+ }}$requirementWithoutSudo"
	fi; then
	    [ "$isVerbose" ] && messagePrintf 'Skipping because requirement %s is not passed: %s\n' "$requirement" "$definition"
	    return 1
	fi
    fi
    return 0
}
isDefinitionGroupAcceptedByGroupRequire()
{
    isDefinitionAcceptedByRequire "$@"
}

definitionFilterTypeRegistry+=([require:]=Require)
definitionGroupFilterTypeRegistry+=([group-require:]=GroupRequire)
