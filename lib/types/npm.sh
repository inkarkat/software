#!/bin/bash source-this-script

configUsageNpm()
{
    cat <<'HELPTEXT'
npm: items refer to the Node.js package (or "Node modules") installer.
HELPTEXT
}

typeset -A installedNpmPackages=()
isInstalledNpmPackagesAvailable=
getInstalledNpmPackages()
{
    [ "$isInstalledNpmPackagesAvailable" ] && return

    local exitStatus packageDirspec; while IFS=$'\n' read -r packageDirspec || { exitStatus="$packageDirspec"; break; }	# Exit status from the process substitution (<(npm)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	local packageName; packageName="${packageDirspec##*/}"
	if [ -n "$packageName" ]; then
	    installedNpmPackages["$packageName"]=t
	    case ",${DEBUG:-}," in *,setup-software:npm,*) echo >&2 "${PS4}setup-software (npm): Found installed ${packageName}";; esac
	fi
    done < <(npm ls --global --parseable --depth 0 2>/dev/null; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledNpmPackagesAvailable=t
}
typeset -A addedNpmPackages=()
hasNpm()
{
    local npmPackageName="${1:?}"; shift
    if ! getInstalledNpmPackages; then
	echo >&2 "ERROR: Failed to obtain installed Node.js package list; skipping ${npmPackageName}."
	return 99
    fi
    [ "${installedNpmPackages["$npmPackageName"]}" ] || [ "${addedNpmPackages["$npmPackageName"]}" ]
}

addNpm()
{
    local npmPackageName="${1:?}"; shift
    isAvailableOrUserAcceptsNative npm npm 'NPM Node.js package manager' || return $?
    preinstallHook "$npmPackageName"
    addedNpmPackages["$npmPackageName"]=t
    postinstallHook "$npmPackageName"
}

isAvailableNpm()
{
    hasNpm "$@" 2>/dev/null
}

installNpm()
{
    [ ${#addedNpmPackages[@]} -gt 0 ] || return
    local IFS=' '
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }npm install --global ${!addedNpmPackages[*]}")
}

typeRegistry+=([npm:]=Npm)
typeInstallOrder+=([400]=Npm)
