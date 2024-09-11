#!/bin/bash source-this-script

configUsagePipx()
{
    cat <<'HELPTEXT'
pipx:PACKAGE-SPEC items refer to Python CLI apps installed in isolated
environments.
PACKAGE-SPEC is the package name (or an absolute filespec or URL), plus any
optional [DEP1,...] dependency packages in square brackets appended.
HELPTEXT
}

parsePipxPackageName()
{
    local packageSpec="${1:?}"; shift
    local packageName="${packageSpec%%\[*\]}"
    # XXX: Heuristics, not perfect!
    packageName="${packageName##*/}"	# absolute filespecs: strip path
    packageName="${packageName%%.*}"	# strip file extension
    [[ "$packageName" =~ ^-[0-9]+\.[0-9].*$ ]] \
	&& packageName="${packageName%"${BASH_REMATCH[0]}"}"	# strip version
    printf %s "$packageName"
}
parsePipxPackageModules()
{
    local packageSpec="${1:?}"; shift
    [[ "$packageSpec" =~ ^[^]]+\[(.+\])$ ]] && printf %s "${BASH_REMATCH[1]}"
}

typeset -A installedPipxPackages=()
isInstalledPipxPackagesAvailable=
getInstalledPipxPackages()
{
    [ "$isInstalledPipxPackagesAvailable" ] && return
    if ! exists pipx; then
	# A missing pipx means that no Python CLI apps have been installed yet.
	isInstalledPipxPackagesAvailable=t
	return
    fi

    local exitStatus packageSpec remainder; while IFS=$'\t' read -r packageSpec remainder || { exitStatus="$packageSpec"; break; }	# Exit status from the process substitution (<(pipx-list-packages)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	# Python CLI apps can have optional modules selected during installation:
	# PACKAGE[MODULE1,...]. There can only be one app configuration due to the
	# global app name.
	local packageName="$(parsePipxPackageName "$packageSpec")"
	local packageModules="$(parsePipxPackageModules "$packageSpec")"
	installedPipxPackages["$packageName"]="$packageModules"
	case ",${DEBUG:-}," in *,setup-software:pipx,*) echo >&2 "${PS4}setup-software (pipx): Found installed ${packageName}${packageModules:+ with dependencies }${packageModules}";; esac
    done < <(pipx-list-packages --package-spec --global 2>/dev/null; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledPipxPackagesAvailable=t
}

typeset -A addedPipxPackages=()
typeset -A externallyAddedPipxPackages=()
hasPipx()
{
    local packageSpec="${1:?}"; shift
    if ! getInstalledPipxPackages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed Python CLI app list; skipping %s.\n' "$packageSpec"
	return 99
    fi

    local packageName="$(parsePipxPackageName "$packageSpec")"
    local packageModules="$(parsePipxPackageModules "$packageSpec")"
    if [ -z "$packageModules" ]; then
	# Without required modules, just the existence of the package is enough.
	[ -n "${installedPipxPackages["$packageName"]+t}" ] || [ -n "${addedPipxPackages["$packageName"]+t}" ] || [ -n "${externallyAddedPipxPackages["$packageName"]+t}" ]
    else
	# Need to ensure that all required modules already are [about to be] installed.
	test -z "$(comm -23 \
	    <(mergeLists --field-separator , --output-separator $'\n' --sort --omit-empty -- "$packageModules") \
	    <(mergeLists --field-separator , --output-separator $'\n' --sort --omit-empty -- "${installedPipxPackages["$packageName"]}" "${addedPipxPackages["$packageName"]}" "${externallyAddedPipxPackages["$packageName"]}"))"
    fi
}

addPipx()
{
    local packageSpec="${1:?}"; shift
    local packageName="$(parsePipxPackageName "$packageSpec")"
    local packageModules="$(parsePipxPackageModules "$packageSpec")"
    isAvailableOrUserAcceptsGroup pipx "${projectDir}/lib/definitions/pipx" 'pipx Python 3 package manager' || return $?

    # Need to combine installed with added modules.
    local combinedPackageModules="$(mergeLists --field-separator , --sort --omit-empty -- "$packageModules" "${installedPipxPackages["$packageName"]}" "${addedPipxPackages["$packageName"]}" "${externallyAddedPipxPackages["$packageName"]}")"
    local combinedPackageSpec="${packageName}${combinedPackageModules:+[${combinedPackageModules}]}"

    preinstallHook "$combinedPackageSpec"
    addedPipxPackages["$packageName"]="$combinedPackageModules"
    postinstallHook "$combinedPackageSpec"
}

isAvailablePipx()
{
    isQuiet=t hasPipx "$@"
}

installPipx()
{
    [ ${#addedPipxPackages[@]} -gt 0 ] || return
    local collectedQuotedPackageSpecs=
    for packageName in "${!addedPipxPackages[@]}"
    do
	local packageModules="${addedPipxPackages["$packageName"]}"
	local quotedPackageSpec; printf -v quotedPackageSpec %q "${packageName}${packageModules:+[${packageModules}]}"
	collectedQuotedPackageSpecs+="${collectedQuotedPackageSpecs:+ }${quotedPackageSpec}"
    done

    local IFS=' '
    submitInstallCommand "${SUDO}${SUDO:+ }pipx install --global --force $collectedQuotedPackageSpecs"
    # Note: --force to update existing packages when modules have been (potentially) added.
}

typeRegistry+=([pipx:]=Pipx)
typeInstallOrder+=([305]=Pipx)
