#!/bin/bash source-this-script

configUsageDummy()
{
    cat <<'HELPTEXT'
dummy: items can be followed by:
- ITEM: the item will be selected (unless it's already available), but will NOT
  actually be installed. Useful to execute a preinstall action without an actual
  package.
- NAME is an arbitrary name that will be reported as missing and will be
  selected (once).
- NAME:ITEM; the arbitrary NAME will be selected if ITEM has already been
  installed or has already been selected by the user in the current session
  (when prefixed !: neither installed nor selected).
  Other definitions can then require:dummy:NAME, so this offers an abstraction
  over ITEMs (that may be different based on the environment (e.g. apt:firefox
  vs. snap:firefox)) to avoid duplicating related ITEMs (like many postinstall
  actions).
HELPTEXT
}

typeset -A addedDummyPackages=()
typeset -A checkDummyPackages=()
hasDummy()
{
    local dummyPackageName="${1:?}"; shift
    local name="${dummyPackageName#*:}"
    local prefix="${dummyPackageName%"$name"}"
    if [ -n "$prefix" ] && local typeName="${typeRegistry["$prefix"]}" && [ -n "$typeName" ]; then
	local availabilityFunctionName="isAvailable${typeName}"
	if type -t "$availabilityFunctionName" >/dev/null; then
	    "$availabilityFunctionName" "$name"
	    return $?
	else
	    printf >&2 'ERROR: Type %s cannot be used as a dummy item; it does not report availability.\n' "$prefix"
	    exit 3
	fi
    elif [ -n "$prefix" ]; then
	potentialItem="$name"
	local dummyName="${prefix%:}"
	local itemName="${potentialItem#*:}"
	prefix="${potentialItem%"$itemName"}"
	local typeName
	if [ -n "$prefix" ] && typeName="${typeRegistry["$prefix"]}" && [ -n "$typeName" ]; then
	    local availabilityFunctionName="isAvailable${typeName}"
	    if type -t "$availabilityFunctionName" >/dev/null; then
		if "$availabilityFunctionName" "$itemName"; then
		    addedDummyPackages["$dummyName"]=t
		    return 0	# Already installed.
		else
		    # Check on add whether the item has been added; by reporting
		    # this dummy as missing, our addDummy() will later be
		    # invoked, too.
		    checkDummyPackages["$dummyName"]="$potentialItem"
		    return 1	# The dummy will be added together with the ITEM.
		fi
	    else
		printf >&2 'ERROR: Type %s cannot be used as a dummy item; it does not report availability.\n' "$prefix"
		exit 3
	    fi
	elif [[ "$prefix" =~ ^! ]] && typeName="${typeRegistry["${prefix#!}"]}" && [ -n "$typeName" ]; then
	    local availabilityFunctionName="isAvailable${typeName}"
	    if type -t "$availabilityFunctionName" >/dev/null; then
		# For the inverted dummy, it doesn't matter here whether the
		# ITEM is installed or not, as it might still be selected.
		# Check on add whether the item has been added; by reporting
		# this dummy as missing, our addDummy() will later be
		# invoked, too.
		checkDummyPackages["$dummyName"]="$potentialItem"
		return 1	# The dummy will be added together with the ITEM.
	    else
		printf >&2 'ERROR: Type %s cannot be used as a dummy item; it does not report availability.\n' "${prefix#!}"
		exit 3
	    fi
	fi
    fi

    [ "${addedDummyPackages["$dummyPackageName"]}" ]
}

addDummy()
{
    local dummyPackageName="${1:?}"; shift
    local name="${dummyPackageName#*:}"
    local prefix="${dummyPackageName%"$name"}"
    local typeName=; [ -n "$prefix" ] && typeName="${typeRegistry["$prefix"]}"
    if [ -n "$typeName" ]; then
	eval "case \" \${!externallyAdded${typeName}Packages*} \" in
	    *\" externallyAdded${typeName}Packages \"*) externallyAdded${typeName}Packages[\"\$name\"]=t;;
	    *) printf >&2 'ERROR: Type %s cannot be used as a dummy item; it has no dictionary for externally added packages.\\n' \"\$prefix\"
		exit 3;;
	esac"
    elif [ -n "$prefix" ] && \
	local dummyName="${prefix%:}" && \
	local item="${checkDummyPackages["$dummyName"]}" && \
	[ -n "$item" ]
    then
	# NAME references a NAME:ITEM pair; check now whether the ITEM has been
	# added, and if positive, add the dummy package as well, so that other
	# definitions can require: that.
	# Note: If ITEM has indeed been put somewhere before this dummy item in
	# the current definition, it _will_ have been added (together with this
	# dummy item), but as we cannot be sure of that, better check it.
	local itemName="${item#*:}"
	prefix="${item%"$itemName"}"; [ -n "$prefix" ] || exit 3
	local typeName
	if typeName="${typeRegistry["$prefix"]}" && [ -n "$typeName" ]; then
	    local availabilityFunctionName="isAvailable${typeName}"; type -t "$availabilityFunctionName" >/dev/null || exit 3
	    if "$availabilityFunctionName" "$itemName"; then
		# ITEM indeed got added; add dummy package, too.
		addedDummyPackages["$dummyName"]=t
	    fi
	elif [[ "$prefix" =~ ^! ]] && typeName="${typeRegistry["${prefix#!}"]}" && [ -n "$typeName" ]; then
	    local availabilityFunctionName="isAvailable${typeName}"; type -t "$availabilityFunctionName" >/dev/null || exit 3
	    if ! "$availabilityFunctionName" "$itemName"; then
		# ITEM hasn't been installed and also hasn't been added; add the dummy package due to the inversion.
		addedDummyPackages["$dummyName"]=t
	    fi
	else
	    exit 3
	fi
    else
	addedDummyPackages["$dummyPackageName"]=t
    fi
}

isAvailableDummy()
{
    isQuiet=t hasDummy "$@"
}

setInstalledDummyPackages()
{
    local dummyName; for dummyName
    do
	addedDummyPackages["$dummyName"]=t
    done
}

installDummy()
{
    [ ${#addedDummyPackages[@]} -eq 0 ] && return
    addPostinstallContextCommand Dummy setInstalledDummyPackages "${!addedDummyPackages[@]}"
}

typeRegistry+=([dummy:]=Dummy)
typeInstallOrder+=([2]=Dummy)
