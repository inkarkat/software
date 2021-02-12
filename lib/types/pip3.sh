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

    local packageName remainder; while IFS=' ' read -r packageName remainder
    do
	case "$packageName" in
	    Package|+(-))   continue;;	# Skip 2-line header
	    *)		    installedPip3Packages["$packageName"]=t
			    case ",${DEBUG:-}," in *,setup-software:pip3,*) echo >&2 "${PS4}setup-software (pip3): Found installed ${packageName}";; esac
			    ;;
	esac
    done < <(pip3 list 2>/dev/null)

    isInstalledPip3PackagesAvailable=t
}
hasPip3()
{
    ! getInstalledPip3Packages || [ "${installedPip3Packages["${1:?}"]}" ]
}

typeset -a addedPip3Packages=()
addPip3()
{
    isAvailable pip3 && addedPip3Packages+=("${1:?}")
}

installPip3()
{
    [ ${#addedPip3Packages[@]} -gt 0 ] || return
    local IFS=' '
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }pip3 install ${addedPip3Packages[*]}")
}

typeRegistry+=([pip3:]=Pip3)
typeInstallOrder+=([200]=Pip3)
