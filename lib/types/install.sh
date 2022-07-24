#!/bin/bash source-this-script

: ${SETUPSOFTWARE_INSTALL_TEMPLATE_EXTENSION:=.template}

configUsageInstall()
{
    cat <<HELPTEXT
install: items consist of
    [INSTALL-ARGS ...] SOURCE-FILE DEST-FILE
SOURCE-FILE is either relative to the ./etc/files directory tree, or an absolute
filespec and is copied over to (absolute) DEST-FILE unless it already is
up-to-date. If SOURCE-FILE ends with *${SETUPSOFTWARE_INSTALL_TEMPLATE_EXTENSION}, environment variables
(\$VARIABLE / \${VARIABLE}) and shell command substitutions (\$(COMMAND) /
\`COMMAND\`) are evaluated and the result is copied to DEST-FILE.
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

    [ -e "$sourceFile" ] && \
	printf %s "$sourceFile" || \
	return 1
}
parseInstall()
{
    local installItem="${1:?}"; shift
    typeset -a addInstalledFileArgs=("$@")
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

    local addCommand=addInstalledFile
    [ ".$(fileExtension --single -- "$sourceFilespec")" = "$SETUPSOFTWARE_INSTALL_TEMPLATE_EXTENSION" ] && \
	addCommand=addInstalledTemplate

    printf '%q ' "$addCommand" "${addInstalledFileArgs[@]}" "${installArgs[@]}" -- "$sourceFilespec"
    printf %q "$2"
}

typeset -A addedInstallActions=()
typeset -a addedInstallActionList=()
hasInstall()
{
    local installRecord="${1:?}"
    local quotedCheckCommand; quotedCheckCommand="$(parseInstall "$installRecord" --check)" || exit 3
    local quotedInstallCommand; quotedInstallCommand="$(parseInstall "$installRecord")" || exit 3

    [ "${addedInstallActions["$quotedInstallCommand"]}" ] && return 0	# This install action has already been selected for installation.

    local decoration="${decoration["install:$installRecord"]}"
    eval "$(decorateCommand "$quotedCheckCommand" "$decoration")"
}

addInstall()
{
    local installRecord="${1:?}"
    local quotedInstallCommand; quotedInstallCommand="$(parseInstall "$installRecord")" || exit 3
    # Note: Do not support pre-/postinstall hooks here (yet), as there's no good
    # short "name" that we could use. The DEST-FILE's whole path may be a bit
    # long, and just the filename itself may be ambiguous.
    addedInstallActions["$quotedInstallCommand"]="$installRecord"
    addedInstallActionList+=("$quotedInstallCommand")
}
installInstall()
{
    [ ${#addedInstallActions[@]} -eq ${#addedInstallActionList[@]} ] || { echo >&2 'ASSERT: Install actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedInstallActionList[@]} -gt 0 ] || return

    local quotedInstallCommand; for quotedInstallCommand in "${addedInstallActionList[@]}"
    do
	submitInstallCommand "$quotedInstallCommand" "${decoration["install:${addedInstallActions["$quotedInstallCommand"]}"]}"
    done
}

typeRegistry+=([install:]=Install)
typeInstallOrder+=([880]=Install)
