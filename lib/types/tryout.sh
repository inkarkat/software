#!/bin/bash source-this-script

configUsageTryout()
{
    cat <<'HELPTEXT'
tryout: items will only be considered if the environment variable TRYOUT is set.
HELPTEXT
}

if [ -n "$TRYOUT" ]; then
    isDefinitionAcceptedByTryout()
    {
	return 0
    }
else
    isDefinitionAcceptedByTryout()
    {
	shift # requirement
	local definition="${1:?}"; shift

	[ "$isVerbose" ] && printf >&2 'Skipping tryout definition because TRYOUT is not set: %s\n' "$definition"
	return 1
    }
fi

definitionFilterTypeRegistry+=([tryout:]=Tryout)
