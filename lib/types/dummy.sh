#!/bin/bash source-this-script

configUsageDummy()
{
    cat <<'HELPTEXT'
dummy: either another ITEM that will be selected (unless it's already
available), but will NOT actually installed, or an arbitrary NAME that is
reported as missing and will be selected (once).
Useful to execute a preinstall action without an actual package.
HELPTEXT
}

typeset -A addedDummyPackages=()
hasDummy()
{
    local dummyPackageName="${1:?}"; shift
    local name="${dummyPackageName#*:}"
    local prefix="${dummyPackageName%"$name"}"
    local typeFunction=; [ -n "$prefix" ] && typeFunction="${typeRegistry["$prefix"]}"
    if [ -n "$typeFunction" ]; then
	local availabilityFunctionName="isAvailable${typeFunction}"
	if type -t "$availabilityFunctionName" >/dev/null; then
	    "$availabilityFunctionName" "$name"
	else
	    printf >&2 'ERROR: Type %s cannot be used as a dummy item; it does not report availability.\n' "$prefix"
	    exit 3
	fi
    else
	[ "${addedDummyPackages["$dummyPackageName"]}" ]
    fi
}

addDummy()
{
    local dummyPackageName="${1:?}"; shift
    local name="${dummyPackageName#*:}"
    local prefix="${dummyPackageName%"$name"}"
    local typeFunction=; [ -n "$prefix" ] && typeFunction="${typeRegistry["$prefix"]}"
    if [ -n "$typeFunction" ]; then
	local externallyAddedDict="externallyAdded${typeFunction}Packages"
	if [ -n "${externallyAddedDict+t}" ]; then
	    eval "$externallyAddedDict[\"\$name\"]=t"
	else
	    printf >&2 'ERROR: Type %s cannot be used as a dummy item; it has no dictionary for externally added packages.\n' "$prefix"
	    exit 3
	fi
    else
	addedDummyPackages["$dummyPackageName"]=t
    fi
}

isAvailableDummy()
{
    hasDummy "$@" 2>/dev/null
}

installDummy()
{
    :
}

typeRegistry+=([dummy:]=Dummy)
typeInstallOrder+=([0]=Dummy)
