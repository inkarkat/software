#!/bin/bash source-this-script

configUsagePpa()
{
    cat <<'HELPTEXT'
ppa:USER[/PPA-NAME] items refer to Ubuntu personal package archives that enable
additional packages (or other versions) to be installed through apt.
You can provide a fallback release codename that will be tried if the PPA
doesn't offer the current release yet: ppa:'USER[/PPA-NAME] (FALLBACK)'
HELPTEXT
}

typeRegistry+=([ppa:]=Ppa)
typeInstallOrder+=([11]=Ppa)

if ! exists apt-add-repository; then
    hasPpa() { return 98; }
    installPpa() { :; }
    isAvailablePpa() { return 98; }
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
typeset -A externallyAddedPpaRepositories=()
hasPpa()
{
    local arg="${1:?}"; shift
    local ppaRepoName="${arg% \(*\)}"
    if ! getInstalledPpaRepositories; then
	messagePrintf >&2 'ERROR: Failed to obtain installed Ubuntu personal package archives list; skipping %s.\n' "$ppaRepoName"
	return 99
    fi
    [ "${installedPpaRepositories["$ppaRepoName"]}" ] || [ "${addedPpaRepositories["$ppaRepoName"]}" ] || [ "${externallyAddedPpaRepositories["$ppaRepoName"]}" ]
}

addPpa()
{
    local arg="${1:?}"; shift
    local ppaRepoName="${arg% \(*\)}"
    isAvailableOrUserAcceptsNative --preinstall apt-add-repository software-properties-common 'apt repository abstraction' || return $?

    preinstallHook "$ppaRepoName"
    addedPpaRepositories["$arg"]=t
    postinstallHook "$ppaRepoName"
}

isAvailablePpa()
{
    isQuiet=t hasPpa "$@"
}

installPpa()
{
    [ ${#addedPpaRepositories[@]} -gt 0 ] || return
    local isSingleRepository; [ ${#addedPpaRepositories[@]} -eq 1 ] && isSingleRepository=t
    local repo; for repo in "${!addedPpaRepositories[@]}"
    do
	if [[ "$repo" =~ \ \((.*)\)$ ]]; then
	    local codename="${BASH_REMATCH[1]}"
	    repo="${repo% \(*\)}"
	    if apt-add-debline --name dummy --validate -- "ppa:$repo"; then
		submitInstallCommand \
		    "${SUDO}${SUDO:+ }apt-add-repository${isBatch:+ --yes}${isSingleRepository:+ --update} ppa:$repo" \
		    "${decoration["ppa:$repo"]}"
	    else
		submitInstallCommand "apt-add-debline${isSingleRepository:+ --update} --name ${repo//\//-} --codename $codename -- ppa:$repo" \
		    "${decoration["ppa:$repo"]}"
	    fi
	else
	    submitInstallCommand \
		"${SUDO}${SUDO:+ }apt-add-repository${isBatch:+ --yes}${isSingleRepository:+ --update} ppa:$repo" \
		"${decoration["ppa:$repo"]}"
	fi
    done
    [ "$isSingleRepository" ] || submitInstallCommand "${SUDO}${SUDO:+ }apt${isBatch:+ --assume-yes} update"
}
