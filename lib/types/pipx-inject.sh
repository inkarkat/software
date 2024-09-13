#!/bin/bash source-this-script

configUsagePipxInject()
{
    cat <<'HELPTEXT'
pipx-inject: items consist of
    MAIN-PACKAGE-NAME DEPENDENCY-PACKAGE-SPEC
MAIN-PACKAGE-NAME is a Python CLI app (just the package name, not the full
package spec!)
DEPENDENCY-PACKAGE-SPEC is the package spec of package dependency that is
injected into the app's environment.
HELPTEXT
}

typeset -A installedPipxInjectPackages=()
typeset -A addedPipxInjectPackages=()
typeset -A externallyAddedPipxInjectPackages=()
hasPipxInject()
{
    local mainPackageName dependencyPackageSpec
    IFS=' ' read -r mainPackageName dependencyPackageSpec <<<"${1:?}"; shift
    if [ -z "$mainPackageName" -o -z "$dependencyPackageSpec" ]; then
	printf >&2 'ERROR: Invalid pipx-inject item: "pipx-inject:%s"\n' "$1"
	exit 3
    fi

    if [ -z "${installedPipxInjectPackages["$mainPackageName"]+t}" ]; then
	installedPipxInjectPackages["$mainPackageName"]="$(pipx-list-injected --global --package-spec "$mainPackageName" 2>/dev/null)"
	case ",${DEBUG:-}," in *,setup-software:pipx-inject,*) echo >&2 "${PS4}setup-software (pipx-inject): Found injected ${installedPipxInjectPackages["$mainPackageName"]//$'\n'/ } for ${mainPackageName}";; esac
    fi
    {
	printf '%s\n' "${addedPipxInjectPackages["$mainPackageName"]}" "${externallyAddedPipxInjectPackages[@]}" "${installedPipxInjectPackages["$mainPackageName"]}"
    } | grep --quiet --fixed-strings --line-regexp "$dependencyPackageSpec"
}

addPipxInject()
{
    local record="${1:?}"; shift
    local mainPackageName dependencyPackageSpec
    IFS=' ' read -r mainPackageName dependencyPackageSpec <<<"$record"

    preinstallHook "$record"
    addedPipxInjectPackages["$mainPackageName"]+=$'\n'"$dependencyPackageSpec"   # Allow duplicates for now.
    postinstallHook "$record"
}

isAvailablePipxInject()
{
    isQuiet=t hasPipxInject "$@"
}

installPipxInject()
{
    [ ${#addedPipxInjectPackages[@]} -gt 0 ] || return
    for mainPackageName in "${!addedPipxInjectPackages[@]}"
    do
	typeset -a uniqueDependencyPackageSpecs=()
	readarray -t uniqueDependencyPackageSpecs < <(printf '%s\n' "${addedPipxInjectPackages["$mainPackageName"]}" | sort --unique | grep -v '^$')
	local quotedArgs; printf -v quotedArgs ' %q' "$mainPackageName" "${uniqueDependencyPackageSpecs[@]}"
	submitInstallCommand "${SUDO}${SUDO:+ }pipx inject --global$quotedArgs"
    done
}

typeRegistry+=([pipx-inject:]=PipxInject)
typeInstallOrder+=([307]=PipxInject)
