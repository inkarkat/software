#!/bin/bash source-this-script

configUsagePip3()
{
    cat <<'HELPTEXT'
pip3: items refer to the Python package installer.
HELPTEXT
}

typeset -A installedPip3Packages=()
isInstalledPip3PackagesAvailable=
getInstalledPip3Packages()
{
    [ "$isInstalledPip3PackagesAvailable" ] && return
    if ! exists pip3; then
	# A missing pip3 means that no Python packages have been installed yet.
	isInstalledPip3PackagesAvailable=t
	return
    fi

    local exitStatus packageName remainder; while IFS=' ' read -r packageName remainder || { exitStatus="$packageName"; break; }	# Exit status from the process substitution (<(pip3)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	case "$packageName" in
	    Package|+(-))   continue;;	# Skip 2-line header
	    *)		    installedPip3Packages["$packageName"]=t
			    case ",${DEBUG:-}," in *,setup-software:pip3,*) echo >&2 "${PS4}setup-software (pip3): Found installed ${packageName}";; esac
			    ;;
	esac
    done < <(PIP_REQUIRE_VIRTUALENV=false pip3 list 2>/dev/null; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledPip3PackagesAvailable=t
}

typeset -A addedPip3Packages=()
typeset -A externallyAddedPip3Packages=()
hasPip3()
{
    local pip3PackageName="${1:?}"; shift
    if ! getInstalledPip3Packages; then
	messagePrintf >&2 'ERROR: Failed to obtain installed Python package list; skipping %s.\n' "$pip3PackageName"
	return 99
    fi

    # Python packages can have optional modules: PACKAGE[MODULE]; unfortunately,
    # that cannot be queried from "pip3 list". Assume that such modules are
    # selected in the same session as and in addition to the base package.
    local pip3BasePackageName="${pip3PackageName%\[*\]}"
    [ "${installedPip3Packages["$pip3BasePackageName"]}" ] || [ "${addedPip3Packages["$pip3PackageName"]}" ] || [ "${externallyAddedPip3Packages["$pip3PackageName"]}" ]
}

addPip3()
{
    local pip3PackageName="${1:?}"; shift
    isAvailableOrUserAcceptsNative pip3 python3-pip 'pip3 Python 3 package manager' || return $?

    preinstallHook Pip3 "$pip3PackageName"
    addedPip3Packages["$pip3PackageName"]=t
    postinstallHook Pip3 "$pip3PackageName"
}

isAvailablePip3()
{
    isQuiet=t hasPip3 "$@"
}

installPip3()
{
    [ ${#addedPip3Packages[@]} -gt 0 ] || return
    local IFS=' '
    submitInstallCommand "${SUDO}${SUDO:+ }PIP_BREAK_SYSTEM_PACKAGES=1 pip3${isBatch:+ --yes} install ${!addedPip3Packages[*]}"
}

typeRegistry+=([pip3:]=Pip3)
typeInstallOrder+=([300]=Pip3)
