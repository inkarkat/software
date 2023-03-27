#!/bin/bash

printUsage()
{
    cat <<HELPTEXT
Clone GIT-REPO or fetch upstream at LOCATION, check out any changes [on BRANCH],
and execute BUILD-COMMAND.
HELPTEXT
    echo
    printf 'Usage: %q %s\n' "$(basename "$1")" 'LOCATION GIT-URL BRANCH RESULT-FILE BUILD-COMMAND [-?|-h|--help]'
}
case "$1" in
    --help|-h|-\?)	shift; printUsage "$0"; exit 0;;
esac

location="${1:?}"; shift
gitUrl="${1:?}"; shift
branch="${1?}"; shift
resultFile="${1:?}"; shift
buildCommand="${1:?}"; shift
if [ $# -ne 0 ]; then
    printUsage "$0" >&2
    exit 2
elif ! exists git; then
    echo >&2 'ERROR: Need to install Git first.'
    exit 3
elif ! exists git-iscontrolled; then
    pathDiscover --quiet
    if ! exists git-iscontrolled; then
	echo >&2 'ERROR: Cannot find my Git extensions.'
	exit 3
    fi
fi

[ -d "$location" ] || mkdir --parents -- "$location" || exit 1
cd "$location" || exit $?

if git-iscontrolled .; then
    originalRev="$(git rev-parse HEAD)"

    GIT_UP_PREFER_DETACHED_TAG_OVER_BRANCH=t git ufetchup-hushed

    updatedRev="$(git rev-parse HEAD)"
    if [ "$updatedRev" = "$originalRev" ]; then
	if [ -e "$resultFile" ]; then
	    printf >&2 'No updates, and %s already exists.' "$resultFile"
	    exit 99
	else
	    printf 'No updates, but %s needs to be built.' "$resultFile"
	fi
    fi
else
    if ! emptydir .; then
	printf >&2 'ERROR: Cannot clone into a non-empty directory: %s\n' "$location"
	exit 3
    fi

    tagGlob=''
    if [ -n "$branch" ] && isglob "$branch"; then
	tagGlob="$branch"
	branch=''
    fi

    git clone --origin upstream --recursive ${branch:+--branch "$branch"} "$gitUrl" . || exit $?

    if [ -n "$tagGlob" ]; then
	latestTag="$(git taglist --list "$tagGlob" | tail -n 1)"
	if [ -n "$latestTag" ]; then
	    git checkout "$latestTag" || exit 3
	else
	    printf >&2 "Warning: No tag matching '%s' found; staying on the default branch %s.\\n" "$tagGlob" "$(git brname)"
	fi
    fi
fi

: ${SUDO:=sudo}; [ $EUID -eq 0 ] && SUDO=''
eval "$buildCommand"
