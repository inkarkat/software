#!/bin/bash source-this-script

configUsageInstall()
{
    cat <<'HELPTEXT'
install: items consist of
    [INSTALL-ARGS ...] SOURCE-FILE DEST-FILE
SOURCE-FILE is either relative to the ./etc/files directory tree, or an absolute
filespec and is copied over to (absolute) DEST-FILE unless it already is
up-to-date.
You can specify additional install arguments:
    --sudo		Do the copy with sudo unless already running as the
			superuser.
    --owner=OWNER	Set ownership (this will automatically use --sudo then)
    --group=GROUP	Set group ownership.
    --mode=MODE		Set permission mode (as in chmod), instead of rwxr-xr-x
    --compare|-C	Compare SOURCE-FILE and DEST-FILE, and in some cases do
			not modify the destination at all
    --preserve-timestamps|-p
			Apply access/modification times of SOURCE-FILE to
			DEST-FILE.
    --backup[=CONTROL]	Make a backup of an existing DEST-FILE.
    -b			Like --backup but does not accept an argument.
    --suffix|-S SUFFIX	Override the usual backup suffix.
    --preserve-context	Preserve SELinux security context.
    -Z			Set SELinux security context of destination file to
			default type.
A missing path to DEST-FILE is created automatically.
HELPTEXT
}

getInstallFilespec()
{
    local sourceFile="${1:?}"; shift

    local dirspec; for dirspec in "${additionalBaseDirs[@]}" "$baseDir"
    do
	local sourceFilespec="${dirspec}/files/${sourceFile}"
	if [ -e "$sourceFilespec" ]; then
	    printf %s "$sourceFilespec"
	    return 0
	fi
    done
    return 1
}
parseInstall()
{
    local installItem="${1:?}"; shift
    eval "set -- $installItem"

    typeset -a installArgs=()
    while [ $# -ne 0 ]
    do
	case "$1" in
	    --owner|-o)	installArgs+=(--sudo "$1" "$2"); shift; shift;;
	    --owner=*)	installArgs+=(--sudo "$1"); shift;;

	    -+([bpCZ]))	installArgs+=("$1"); shift;;
	    --@(compare|preserve-context|preserve-timestamps|sudo))
			installArgs+=("$1"); shift;;
	    -[gmS])	installArgs+=("$1" "$2"); shift; shift;;
	    --@(backup|group|mode|suffix)=*)
			installArgs+=("$1"); shift;;
	    --@(group|mode|suffix))
			installArgs+=("$1" "$2"); shift; shift;;

	    --)		shift; break;;
	    -*)		printf >&2 'ERROR: Invalid install item: "install:%s" due to invalid "%s".\n' "$installItem" "$1"; exit 3;;
	    *)		break;;
	esac
    done
    if [ $# -ne 2 ]; then
	printf >&2 'ERROR: Invalid install item: "install:%s" due to missing SOURCE-FILE DEST-FILE.\n' "$installItem"
	exit 3
    fi

    local sourceFilespec; if ! sourceFilespec="$(getInstallFilespec "$1")"; then
	if [ ! -e "$1" ]; then
	    printf >&2 'ERROR: Invalid install item: "install:%s" due to missing SOURCE-FILE: "%s".\n' "$installItem" "$1"
	    exit 3
	fi
	sourceFilespec="$1"
    fi

    printf '%q ' "${installArgs[@]}" -- "$sourceFilespec" "$2"
}

typeset -A addedInstallActions=()
typeset -a addedInstallActionList=()
hasInstall()
{
    local quotedInstallArgs
    quotedInstallArgs="$(parseInstall "${1:?}")" || exit 3

    [ "${addedInstallActions["$quotedInstallArgs"]}" ] && return 0	# This install action has already been selected for installation.

    eval "addInstalledFile --check $quotedInstallArgs"
}

addInstall()
{
    local quotedInstallArgs="$(parseInstall "${1:?}")"

    # Note: Do not support pre-/postinstall hooks here (yet), as there's no good
    # short "name" that we could use. The DEST-FILE's whole path may be a bit
    # long, and just the filename itself may be ambiguous.
    addedInstallActions["$quotedInstallArgs"]=t
    addedInstallActionList+=("$quotedInstallArgs")
}
installInstall()
{
    [ ${#addedInstallActions[@]} -eq ${#addedInstallActionList[@]} ] || { echo >&2 'ASSERT: Install actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedInstallActionList[@]} -gt 0 ] || return

    local quotedInstallArgs; for quotedInstallArgs in "${addedInstallActionList[@]}"
    do
	toBeInstalledCommands+=("addInstalledFile $quotedInstallArgs")
    done
}

typeRegistry+=([install:]=Install)
typeInstallOrder+=([880]=Install)
