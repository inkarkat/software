#!/bin/bash source-this-script

configUsageAmazonExtras()
{
    cat <<'HELPTEXT'
amazon-extras: items refer to Amazon Linux Extras software topics.
HELPTEXT
}

typeRegistry+=([amazon-extras:]=AmazonExtras)
typeInstallOrder+=([210]=AmazonExtras)

if ! exists amazon-linux-extras; then
    hasAmazonExtras() { return 98; }
    installAmazonExtras() { :; }
    isAvailableAmazonExtras() { return 98; }
    return
fi

typeset -A installedAmazonExtrasPackages=()
isInstalledAmazonExtrasPackagesAvailable=
getInstalledAmazonExtrasPackages()
{
    [ "$isInstalledAmazonExtrasPackagesAvailable" ] && return
    local exitStatus packageName remainder; while IFS='=' read -r packageName packageVersion || { exitStatus="$packageName"; break; }	# Exit status from the process substitution (<(amazon-linux-extras)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedAmazonExtrasPackages["$packageName"]=t
	case ",${DEBUG:-}," in *,setup-software:amazon-extras,*) echo >&2 "${PS4}setup-software (amazon-extras): Found installed ${packageName}";; esac
    done < <(amazon-linux-extras list | joinLineContinuation | joinUntilClosingPair --pair '[]' | fieldGrep -e enabled 3 | field 2 2>/dev/null; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledAmazonExtrasPackagesAvailable=t
}

typeset -A addedAmazonExtrasPackages=()
typeset -A externallyAddedAmazonExtrasPackages=()
hasAmazonExtras()
{
    local amazonExtrasPackageName="${1:?}"; shift
    if ! getInstalledAmazonExtrasPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed Python package list; skipping %s.\n' "$amazonExtrasPackageName"
	return 99
    fi
    [ "${installedAmazonExtrasPackages["$amazonExtrasPackageName"]}" ] || [ "${addedAmazonExtrasPackages["$amazonExtrasPackageName"]}" ] || [ "${externallyAddedAmazonExtrasPackages["$amazonExtrasPackageName"]}" ]
}

addAmazonExtras()
{
    local amazonExtrasPackageName="${1:?}"; shift

    preinstallHook AmazonExtras "$amazonExtrasPackageName"
    addedAmazonExtrasPackages["$amazonExtrasPackageName"]=t
    postinstallHook AmazonExtras "$amazonExtrasPackageName"
}

isAvailableAmazonExtras()
{
    isQuiet=t hasAmazonExtras "$@"
}

installAmazonExtras()
{
    [ ${#addedAmazonExtrasPackages[@]} -gt 0 ] || return
    local IFS=' '
    submitInstallCommand "${SUDO}${SUDO:+ }amazon-linux-extras install${isBatch:+ -y} ${!addedAmazonExtrasPackages[*]}"
}
