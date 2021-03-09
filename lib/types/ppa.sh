#!/bin/bash source-this-script

configUsagePpa()
{
    cat <<'HELPTEXT'
ppa: items refer to Ubuntu personal package archives that enable additional
packages (or other versions) to be installed through apt.
HELPTEXT
}

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
typeset -A addedPpaRepositories=()
hasPpa()
{
    ! getInstalledPpaRepositories || [ "${addedPpaRepositories["${1:?}"]}" ] || [ "${installedPpaRepositories["${1:?}"]}" ]
}

addPpa()
{
    local ppaRepoName="${1:?}"; shift

    preinstallHook "$ppaRepoName"
    addedPpaRepositories["$ppaRepoName"]=t
    postinstallHook "$ppaRepoName"
}

isAvailablePpa()
{
    local ppaRepoName="${1:?}"; shift
    getInstalledPpaRepositories || return $?
    [ "${installedPpaRepositories["$ppaRepoName"]}" ] || contains "$ppaRepoName" "${!addedPpaRepositories[@]}"
}

installPpa()
{
    [ ${#addedPpaRepositories[@]} -gt 0 ] || return
    local repo; for repo in "${!addedPpaRepositories[@]}"
    do
	toBeInstalledCommands+=("${SUDO}${SUDO:+ }add-apt-repository ppa:$repo")
    done
    toBeInstalledCommands+=("${SUDO}${SUDO:+ }apt update")
}

typeRegistry+=([ppa:]=Ppa)
typeInstallOrder+=([1]=Ppa)
