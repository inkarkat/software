#!/bin/bash

: ${SUDO:=sudo}; [ $EUID -eq 0 ] && SUDO=''
case ",${DEBUG:-}," in *,sudo,*) SUDO="verbose $SUDO";; *,sudo\!,*) SUDO="echotrace $SUDO";; esac

: ${LINUXBREW_HOME:=/home/linuxbrew}
: ${LINUXBREW_PREFIX:=${LINUXBREW_HOME}/.linuxbrew}
: ${BASH_LOGIN_FILESPEC:=${LINUXBREW_HOME}/.bash_login}

printUsage()
{
    cat <<HELPTEXT
Install the Homebrew package manager under a service account so that regular
users have to be a member of the linuxbrew group to use its packages and use
sudo to change packages.
HELPTEXT
    echo
    printf 'Usage: [DEBUG=sudo[!]] %q %s\n' "$(basename "$1")" '[--check] [-?|-h|--help]'
}

ECHO=echo
typeset -a checkArg=()
isCheck=
case "$1" in
	--help|-h|-\\?)	shift; printUsage "$0"; exit 0;;
	--check)	checkArg=("$1"); shift; ECHO=:; isCheck=t; set -e;; # set -e aborts on the first failing check, but failures in the actual setup will continue with the next.
	-*)		{ echo "ERROR: Unknown option \"$1\"!"; echo; printUsage "$0"; } >&2; exit 2;;
esac
if [ $# -ne 0 ]; then
    printUsage "$0" >&2
    exit 2
fi

# Linux system account; i.e. dedicated user and group.
isNewBrewSystemAccount=
if ! getent group linuxbrew >/dev/null 2>&1 \
    || ! getent passwd linuxbrew >/dev/null 2>&1
then
    [ "$isCheck" ] && exit 1
    $SUDO adduser --system --group --home "$LINUXBREW_HOME" --shell /bin/bash linuxbrew || exit $?
    isNewBrewSystemAccount=t
fi

# For the cache, allow write access for the linuxbrew group and read access to
# others. Homebrew stores downloaded packages and meta information there, and we
# put the brew-version in there.
addDir --sudo "${checkArg[@]}" --owner linuxbrew --group linuxbrew --mode 775 -- "${LINUXBREW_HOME}/.cache"

# Allow read access to the system account's home directory itself; all Homebrew
# files are in the ./.linuxbrew/ subdir, anyway. This simplifies the following
# checks for .bash_login.
if ! hasFileAttributes --mode o+rx -- "$LINUXBREW_HOME"; then
    [ "$isCheck" ] && exit 1
    $SUDO chmod o+rx -- "$LINUXBREW_HOME" || exit $?
fi

checkedAddOrUpdate "${checkArg[@]}" \
	--sudo-command sudoWithUnixhome \
	--no-subsequent-backup \
	addOrUpdateLine \
		--create-nonexisting \
		--line 'umask 0027  # Group is read-only, others have no access.' \
		-- "$BASH_LOGIN_FILESPEC"

checkedAddOrUpdate "${checkArg[@]}" \
	--sudo-command sudoWithUnixhome \
	--no-subsequent-backup \
	addOrUpdateLine \
		--create-nonexisting \
		--line "eval \"\$(${LINUXBREW_PREFIX}/bin/brew shellenv bash)\"" \
		-- "$BASH_LOGIN_FILESPEC"

[ "$isCheck" ] || $SUDO chown linuxbrew:linuxbrew -- "$BASH_LOGIN_FILESPEC" || exit $?

hasBrew()
{
    [ -x "${LINUXBREW_PREFIX}/bin/brew" ] && return 0
    [ -d "$LINUXBREW_PREFIX" ] || return 1	# Our user is able to read the user's home directory, but not the contents of the .linuxbrew tree.

    # System account just got set up; can't be installed yet.
    [ "$isNewBrewSystemAccount" ] && return 1

    # If the current user in the current session is not in the linuxbrew group, they
    # cannot check; need to use the linuxbrew user.
    isBelongsToGroup linuxbrew && return 1  # Our user was able to check, didn't find it.
    sudo --user linuxbrew bash -c "[ -x '${LINUXBREW_PREFIX}/bin/brew' ]"
}

if ! hasBrew; then
    [ "$isCheck" ] && exit 1
    sudo --user linuxbrew --set-home --login bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' || exit $?

    cat <<'EOF'
✓ Homebrew installed. Access the 'brew' command via
  $ sudo --user linuxbrew --set-home --login brew SUBCOMMAND ...
EOF
fi
