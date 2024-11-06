#!/bin/bash source-this-script

: ${GITREPO_BASEDIR:=~/src}

configUsageGitrepo()
{
    cat <<'HELPTEXT'
gitrepo: items consist of a
    NAME[:MAX-AGE[SUFFIX]]:GIT-URL[:(BRANCH|TAG|TAG-GLOB|HASH)]:RESULT-FILE:(BUILD-EXPRESSION|BUILD-FILE)
quadruplet / quintuplet / sextuplet.
If no Git working copy exists yet at ${GITREPO_BASEDIR}/NAME (NAME can also be
an absolute path), the Git repository at GIT-URL is cloned there [and BRANCH (or
a TAG, or the highest version matching TAG-GLOB, or a commit HASH) checked out].
If the last pull date is older than MAX-AGE[SUFFIX], the remote will be checked
for changes on the branch / a newer tag, and if such exist, these will be
checked out. BUILD-EXPRESSION or BUILD-FILE (either relative to the ./etc/files
directory tree, or an absolute filespec)is executed unless there have been no
updates and RESULT-FILE (absolute or relative to the working copy root) already
exists.
HELPTEXT
}

parseGitrepo()
{
    local gitrepoRecord="${1:?}"; shift
    if [[ ! "$gitrepoRecord" =~ ^[^:[:space:]]+:[^:[:space:]]+:[^:]+:.+ ]]; then
	printf >&2 'ERROR: Invalid gitrepo item: "gitrepo:%s"\n' "$gitrepoRecord"
	return 3
    fi

    local name="${gitrepoRecord%%:*}"
    local remainder="${gitrepoRecord#${name}:}"

    [[ "$name" =~ ^/ ]] \
	&& local location="$name" \
	|| local location="${GITREPO_BASEDIR}/${name}"

    local maxAge=
    if [[ "$remainder" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	maxAge="${BASH_REMATCH[0]%:}"
	remainder="${remainder#"${BASH_REMATCH[0]}"}"
    fi
    if [[ ! "$remainder" =~ ^((/|[^:[:space:]]+://|[^:[:space:]]+@[^:[:space:]]+:)[^:[:space:]]+)(:([^:[:space:]]+))?:([^:[:space:]]+):(.+)$ ]]; then
	printf >&2 'ERROR: Invalid gitrepo item: "gitrepo:%s"\n' "$gitrepoRecord"
	return 3
    fi
    local gitUrl="${BASH_REMATCH[1]}"
    local branch="${BASH_REMATCH[4]}"
    local resultFile="${BASH_REMATCH[5]}"

    local buildCommand="${BASH_REMATCH[6]}"
    local buildFilespec; buildFilespec="$(getAbsoluteOrFilesFilespec "$buildCommand")" \
	&& buildCommand="$buildFilespec"

    printf 'local %s=%q\n' location "$location" maxAge "$maxAge" gitUrl "$gitUrl" branch "$branch" resultFile "$resultFile" buildCommand "$buildCommand"
}

typeset -A addedGitrepoLocations=()
typeset -a addedGitrepoRecords=()
hasGitrepo()
{
    local parse; parse="$(parseGitrepo "${1:?}")" || exit 3; eval "$parse"

    [ "${addedGitrepoLocations["${location:?}"]}" ] && return 0

    [ -d "$location" ] || return 1
    exists git || return 99
    exists git-iscontrolled || return 99
    git-iscontrolled "$location" || return 1

    if [ -n "${maxAge?}" ] \
	&& git-inside fetchdate --remote upstream --older "$maxAge" -- "$location"
    then
	translateStatus 3+=99 git-inside uptodate --quiet upstream -- "$location" || return $?
    fi

    local quotedResultFile; printf -v quotedResultFile '%q' "$resultFile"
    git-inside --command "test -e $quotedResultFile" -- "$location"
}

addGitrepo()
{
    local gitrepoRecord="${1:?}"; shift
    local parse; parse="$(parseGitrepo "$gitrepoRecord")" || exit 3; eval "$parse"
    local name="$(basename -- "${location:?}")"

    isAvailableOrUserAcceptsNative git || return $?

    preinstallHook "$name"
    addedGitrepoLocations["$location"]=t
    addedGitrepoRecords+=("$gitrepoRecord")
    postinstallHook "$name"
}

isAvailableGitrepo()
{
    isQuiet=t hasGitrepo "$@"
}

installGitrepo()
{
    local gitrepoRecord; for gitrepoRecord in "${addedGitrepoRecords[@]}"
    do
	local parse; parse="$(parseGitrepo "$gitrepoRecord")" || exit 3; eval "$parse"
	local quotedGitrepoInstallCommand; printf -v quotedGitrepoInstallCommand '%q ' \
	    "${projectDir}/lib/gitrepoInstall.sh" \
	    "${location:?}" "${gitUrl:?}" "${branch?}" "${resultFile:?}" "${buildCommand:?}"
	submitInstallCommand "${quotedGitrepoInstallCommand% }" "${decoration["gitrepo:${gitrepoRecord}"]}"
    done
}

typeRegistry+=([gitrepo:]=Gitrepo)
typeInstallOrder+=([710]=Gitrepo)
