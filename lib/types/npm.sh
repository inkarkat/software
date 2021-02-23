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

    local packageDirspec; while IFS=$'\n' read -r packageDirspec
    do
	local packageName; packageName="${packageDirspec##*/}"
	if [ -n "$packageName" ]; then
	    installedNpmPackages["$packageName"]=t
	    case ",${DEBUG:-}," in *,setup-software:npm,*) echo >&2 "${PS4}setup-software (npm): Found installed ${packageName}";; esac
	fi
    done < <(npm ls --global --parseable --depth 0 2>/dev/null)

    isInstalledNpmPackagesAvailable=t
}
hasNpm()
{
    ! getInstalledNpmPackages || [ "${installedNpmPackages["${1:?}"]}" ]
}

typeset -a addedNpmPackages=()
addNpm()
{
    local npmPackageName="${1:?}"; shift
    isAvailableOrUserAcceptsNative npm npm 'NPM Node.js package manager' || return $?
    preinstallHook "$npmPackageName"
    addedNpmPackages+=("$npmPackageName")
    postinstallHook "$npmPackageName"
}

isAvailableNpm()
{
    local npmPackageName="${1:?}"; shift
    getInstalledNpmPackages || return $?
    [ "${installedNpmPackages["$npmPackageName"]}" ] || [ "${addedNpmPackages["$npmPackageName"]}" ]
}

installNpm()
{
    [ ${#addedNpmPackages[@]} -gt 0 ] || return
    local IFS=' '
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }npm install --global ${addedNpmPackages[*]}")
}

typeRegistry+=([npm:]=Npm)
typeInstallOrder+=([300]=Npm)
