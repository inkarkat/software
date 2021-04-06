#!/bin/bash source-this-script

configUsagePpa()
{
    cat <<'HELPTEXT'
ppa: items refer to Ubuntu personal package archives that enable additional
packages (or other versions) to be installed through apt.
HELPTEXT
}

typeRegistry+=([ppa:]=Ppa)
typeInstallOrder+=([1]=Ppa)

if ! exists add-apt-repository; then
    hasPpa() { return 98; }
    installPpa() { :; }
    return
fi

typeset -A installedPpaRepositories=()
isInstalledPpaRepositoriesAvailable=
getInstalledPpaRepositories()
{
    [ "$isInstalledPpaRepositoriesAvailable" ] && return

    local exitStatus repo; while IFS=$'\n' read -r repo || { exitStatus="$repo"; break; }	# Exit status from the process substitution (<(apt-list-repositories)) is lost; return the actual exit status via an incomplete (i.e. missing the newline) last line.
    do
	installedPpaRepositories["${repo#ppa:}"]=t
	case ",${DEBUG:-}," in *,setup-software:ppa,*) echo >&2 "${PS4}setup-software (ppa): Found installed ppa:${repo}";; esac
    done < <(apt-list-repositories --ppa-only; printf %d "$?")
    [ $exitStatus -eq 0 ] && isInstalledPpaRepositoriesAvailable=t
}
typeset -A addedPpaRepositories=()
hasPpa()
{
    local ppaRepoName="${1:?}"; shift
    if ! getInstalledPpaRepositories; then
	echo >&2 "ERROR: Failed to obtain installed Ubuntu personal package archives list; skipping ${ppaRepoName}."
	return 99
    fi
    [ "${installedPpaRepositories["$ppaRepoName"]}" ] || [ "${addedPpaRepositories["$ppaRepoName"]}" ]
}

addPpa()
{
    local ppaRepoName="${1:?}"; shift
    isAvailableOrUserAcceptsNative --preinstall add-apt-repository software-properties-common 'apt repository abstraction' || return $?

    preinstallHook "$ppaRepoName"
    addedPpaRepositories["$ppaRepoName"]=t
    postinstallHook "$ppaRepoName"
}

isAvailablePpa()
{
    hasPpa "$@" 2>/dev/null
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
