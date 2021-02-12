#!/bin/bash source-this-script

typeset -A installedPpaRepositories=()
isInstalledPpaRepositoriesAvailable=
getInstalledPpaRepositories()
{
    [ "$isInstalledPpaRepositoriesAvailable" ] && return

    local repo; while IFS=$'\n' read -r repo
    do
	installedPpaRepositories["${repo#ppa:}"]=t
	case ",${DEBUG:-}," in *,setup-software:ppa,*) echo >&2 "${PS4}setup-software (ppa): Found installed ppa:${repo}";; esac
    done < <(apt-list-repositories --ppa-only)

    isInstalledPpaRepositoriesAvailable=t
}
hasPpa()
{
    ! getInstalledPpaRepositories || [ "${installedPpaRepositories["${1:?}"]}" ]
}

typeset -a addedPpaRepositories=()
addPpa()
{
    addedPpaRepositories+=("${1:?}")
}

installPpa()
{
    [ ${#addedPpaRepositories[@]} -gt 0 ] || return
    local repo; for repo in "${addedPpaRepositories[@]}"
    do
	toBeInstalledCommands+=("${SUDO}${SUDO:+ }add-apt-repository ppa:$repo")
    done
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }apt update")
}

typeRegistry+=([ppa:]=Ppa)
typeInstallOrder+=([1]=Ppa)
