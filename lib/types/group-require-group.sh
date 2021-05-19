#!/bin/bash source-this-script

configUsageGroupRequire()
{
    cat <<'HELPTEXT'
group-require-group: items refer to a GROUP-NAME. If that group has not yet been
selected (through --all) or passed on the command-line (as GROUP-NAME or
GROUP-FILESPEC), the entire remainder of the definition group (i.e. the
remaining lines in the file) will be skipped.
HELPTEXT
}

isDefinitionGroupAcceptedByGroupRequireGroup()
{
    local groupName="${1:?}"; shift
    local definitionGroupFileAndLocation="${1:?}"; shift

    contains "$groupName" "${acceptedGroups[@]}" "${passedGroups[@]}" && return 0   # GROUP-NAMEs
    containsGlob "*/$groupName" "${passedGroups[@]}" && return 0    # GROUP-FILESPECs

    [ "$isVerbose" ] && messagePrintf 'Skipping definitions for %s because group %s has not been selected.\n' "$definitionGroupFileAndLocation" "$groupName"
    return 1
}

definitionGroupFilterTypeRegistry+=([group-require-group:]=GroupRequireGroup)
