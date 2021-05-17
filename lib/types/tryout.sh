#!/bin/bash source-this-script

configUsageTryout()
{
    cat <<'HELPTEXT'
tryout: stands on its own (nothing is directly following it); the entire
definition (both preceding and following items) will only be considered if the
environment variable TRYOUT is set.
HELPTEXT
}
configUsageGroupTryout()
{
    cat <<'HELPTEXT'
group-tryout: stands on its own (nothing is directly following it); all lines
following it in the definition group will only be considered if the environment
variable TRYOUT is set.
HELPTEXT
}

if [ -n "$TRYOUT" ]; then
    isDefinitionAcceptedByTryout()
    {
	return 0
    }
    isDefinitionGroupAcceptedByGroupTryout()
    {
	return 0
    }
else
    isDefinitionAcceptedByTryout()
    {
	shift # requirement
	local definition="${1:?}"; shift

	[ "$isVerbose" ] && messagePrintf 'Skipping tryout definition because TRYOUT is not set: %s\n' "$definition"
	return 1
    }
    isDefinitionGroupAcceptedByGroupTryout()
    {
	shift # group filter
	local definitionGroupFileAndLocation="${1:?}"; shift

	[ "$isVerbose" ] && messagePrintf 'Skipping tryout definition group filter for %s because TRYOUT is not set\n' "$definitionGroupFileAndLocation"
	return 1
    }
fi

definitionFilterTypeRegistry+=([tryout:]=Tryout)
definitionGroupFilterTypeRegistry+=([group-tryout:]=GroupTryout)
