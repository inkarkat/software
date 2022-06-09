#!/bin/bash source-this-script

configUsageDeprecated()
{
    cat <<'HELPTEXT'
deprecated: stands on its own (nothing is directly following it); the entire
definition (both preceding and following items) will only be considered if the
environment variable DEPRECATED is set.
HELPTEXT
}
configUsageGroupDeprecated()
{
    cat <<'HELPTEXT'
group-deprecated: stands on its own (nothing is directly following it); all
lines following it in the definition group will only be considered if the
environment variable DEPRECATED is set.
HELPTEXT
}

if [ -n "$DEPRECATED" ]; then
    isDefinitionAcceptedByDeprecated()
    {
	return 0
    }
    isDefinitionGroupAcceptedByGroupDeprecated()
    {
	return 0
    }
else
    isDefinitionAcceptedByDeprecated()
    {
	shift # requirement
	local definition="${1:?}"; shift

	[ "$isVerbose" ] && messagePrintf 'Skipping deprecated definition because DEPRECATED is not set: %s\n' "$definition"
	return 1
    }
    isDefinitionGroupAcceptedByGroupDeprecated()
    {
	shift # group filter
	local definitionGroupFileAndLocation="${1:?}"; shift

	[ "$isVerbose" ] && messagePrintf 'Skipping deprecated definition group filter for %s because DEPRECATED is not set\n' "$definitionGroupFileAndLocation"
	return 1
    }
fi

definitionFilterTypeRegistry+=([deprecated:]=Deprecated)
definitionGroupFilterTypeRegistry+=([group-deprecated:]=GroupDeprecated)
