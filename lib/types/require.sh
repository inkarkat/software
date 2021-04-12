#!/bin/bash source-this-script

configUsageRequire()
{
    cat <<'HELPTEXT'
require: items consist of a CHECK that can be:
- another ITEM (in abbreviated form, usually just having one "package name"
  parameter); for packages installed via the distribution's package manager, use
  the special "native:" prefix here. The check passes if that ITEM has already
  been installed or has already been selected by the user in the current
  session.
- an executable command (potentially prefixed with ! (which negates the status,
  just as in the shell) and/or followed by command-line arguments) in the
  ./etc/require directory tree that is invoked and should fail if the
  requirements are not fulfilled.
- a REQUIREMENT-EXPRESSION (whitespace must be escaped or the entire expression
  quoted!) that is eval'd and should fail if the requirements are not fulfilled.
If the CHECK fails, the entire definition (both preceding and following items)
will be skipped.
HELPTEXT
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
	    if ! eval "$availabilityFunctionName \"\$name\""; then
		[ "$isVerbose" ] && printf >&2 'Skipping because requirement %s is not passed: %s\n' "$requirement" "$definition"
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
	local requirementWithoutArgs="${requirement%% *}"
	if ! if [ -x "${requireActionsDirspec}/${requirement}" ]; then
	    "${requireActionsDirspec}/${requirement}"
	elif [ -x "${requireActionsDirspec}/${requirement#!}" ]; then
	    ! "${requireActionsDirspec}/${requirement#!}"
	elif [ -x "${requireActionsDirspec}/${requirementWithoutArgs}" ]; then
	    requirementArgs="${requirement#"${requirementWithoutArgs}"}"
	    "${requireActionsDirspec}/${requirementWithoutArgs}" $requirementArgs
	elif [ -x "${requireActionsDirspec}/${requirementWithoutArgs#!}" ]; then
	    requirementArgs="${requirement#"${requirementWithoutArgs}"}"
	    ! "${requireActionsDirspec}/${requirementWithoutArgs#!}" $requirementArgs
	else
	    eval "$requirement"
	fi; then
	    [ "$isVerbose" ] && printf >&2 'Skipping because requirement %s is not passed: %s\n' "$requirement" "$definition"
	    return 1
	fi
    fi
    return 0
}

definitionFilterTypeRegistry+=([require:]=Require)
