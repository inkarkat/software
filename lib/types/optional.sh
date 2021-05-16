#!/bin/bash source-this-script

configUsageOptional()
{
    cat <<'HELPTEXT'
optional: will cause the entire definition to be queried separately from the
ordinary definitions (so even if you accept any definition, you will be queried
again for optional ones). An optional OPTION-GROUP-NAME will establish separate
namespaces for queries. Automatic installation with --yes will skip optional
definitions, unless --yes-for options|OPTION-GROUP-NAME is also passed.
HELPTEXT
}
configUsageGroupOptional()
{
    cat <<'HELPTEXT'
group-optional: (if it occurs at the beginning of the file, before any actual
definitions) will cause the definition group to be queried separately from the
ordinary definition groups (when --all is given). An optional OPTION-GROUP-NAME
will establish separate namespaces for queries.
HELPTEXT
}

typeset -A yesForNames=()
handleYesFor()
{
    shift   # --yes-for
    local optionGroupName="${1?}"; shift
    yesForNames["${optionGroupName:-optional}"]=t
}

declineOptionalDefinitions()
{
    [ -z "$setupAppendix" ] || [ -n "${yesForNames["$setupAppendix"]}" ]
}

isDefinitionAcceptedByOptional()
{
    local optionGroupName="${1?}"; shift
    shift # definition

    if [ "$obtainSelection" = true ]; then
	# Limit --yes to non-optional definitions.
	obtainSelection=declineOptionalDefinitions
    fi

    # This item does not filter anything; it just modifies the setupAppendix.
    setupAppendix="${optionGroupName:-optional}"
    return 0
}
isDefinitionGroupAcceptedByGroupOptional()
{
    local optionGroupName="${1?}"; shift
    shift; # definitionGroupFileAndLocation

    # This item does not filter anything; it just modifies the setupAppendix.
    setupAppendix="${optionGroupName:-optional}"
    return 0
}

commandLineParameters+=([--yes-for]=handleYesFor)
definitionFilterTypeRegistry+=([optional:]=Optional)
definitionGroupFilterTypeRegistry+=([group-optional:]=GroupOptional)
