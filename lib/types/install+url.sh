#!/bin/bash source-this-script

configUsageInstallUrl()
{
    : ${INSTALL_DIR:=~/install}
    cat <<'HELPTEXT'
install+url: items consist of
    [INSTALL-ARGS ...] [MAX-AGE[SUFFIX]:][[SUBDIR/]NAME/]FILE-GLOB:[URL [...]] DEST-FILE
If ${INSTALL_DIR}/(SUBDIR|*)/(NAME|*)/FILE-GLOB already exists [and if it is
younger than MAX-AGE[SUFFIX]], it will be used; else, URL(s) (first that
succeeds) will be downloaded (and put into ${INSTALL_DIR}/* if it exists) and
copied over to (absolute) DEST-FILE unless it already is up-to-date.
You can specify additional install arguments:
    --sudo		Do the copy with sudo unless already running as the
			superuser.
    --owner=OWNER	Set ownership (this will automatically use --sudo then)
    --group=GROUP	Set group ownership.
    --mode=MODE		Set permission mode (as in chmod), instead of rwxr-xr-x
    --compare|-C	Compare downloaded and DEST-FILE, and in some cases do
			not modify the destination at all
    --preserve-timestamps|-p
			Apply access/modification times of the downloaded file
			to DEST-FILE.
    --backup[=CONTROL]	Make a backup of an existing destination file.
    -b			Like --backup but does not accept an argument.
    --suffix|-S SUFFIX	Override the usual backup suffix.
    --preserve-context	Preserve SELinux security context.
    -Z			Set SELinux security context of destination file to
			default type.
A missing path to DEST-FILE is created automatically.
HELPTEXT
}

parseInstallUrl()
{
    local installUrlItem="${1:?}"; shift
    eval "set -- $installUrlItem"

    typeset -a fileAttributeArgs=()
    typeset -a installArgs=()
    while [ $# -ne 0 ]
    do
	case "$1" in
	    --owner|-o)	installArgs+=(--sudo); fileAttributeArgs+=("$1" "$2"); shift; shift;;
	    --owner=*)	installArgs+=(--sudo); fileAttributeArgs+=("$1"); shift;;
	    --group|-g)	fileAttributeArgs+=("$1" "$2"); shift; shift;;
	    --group=*)	fileAttributeArgs+=("$1"); shift;;
	    --mode|-m)	fileAttributeArgs+=("$1" "$2"); shift; shift;;
	    --mode=*)	fileAttributeArgs+=("$1"); shift;;

	    -+([bpCZ]))	installArgs+=("$1"); shift;;
	    --@(compare|preserve-context|preserve-timestamps|sudo))
			installArgs+=("$1"); shift;;
	    -S)		installArgs+=("$1" "$2"); shift; shift;;
	    --@(backup|suffix)=*)
			installArgs+=("$1"); shift;;
	    --@(suffix))
			installArgs+=("$1" "$2"); shift; shift;;

	    --)		shift; break;;
	    -*)		printf >&2 'ERROR: Invalid install+url item: "install+url:%s" due to invalid "%s".\n' "$installUrlItem" "$1"; exit 3;;
	    *)		break;;
	esac
    done
    if [ $# -lt 2 ]; then
	printf >&2 'ERROR: Invalid install+url item: "install+url:%s" due to missing [MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]FILE-GLOB:[URL [...]] DEST-FILE.\n' "$installUrlItem"
	exit 3
    fi

    local maxAge=
    local applicationNameFileGlobUrl="$1"; shift
    if [[ "$applicationNameFileGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	maxAge="${BASH_REMATCH[0]%:}"
	applicationNameFileGlobUrl="${applicationNameFileGlobUrl#"${BASH_REMATCH[0]}"}"
    fi
    local firstUrl="${applicationNameFileGlobUrl#*:}"
    local applicationNameAndFileGlob="${applicationNameFileGlobUrl%:$firstUrl}"
    local fileGlob="${applicationNameAndFileGlob##*/}"
    local applicationName="${applicationNameAndFileGlob%"$fileGlob"}"
    local outputNameArg=; isglob "$fileGlob" || printf -v outputNameArg %q "$fileGlob"
    printf -v fileGlob %q "$fileGlob"
    applicationName="${applicationName%/}"
    printf -v applicationName %q "$applicationName"
    typeset -a urls=()
    [ -n "$firstUrl" ] && urls+=("$firstUrl")
    urls+=("${@:1:$(($#-1))}")
    local urlArgs; [ ${#urls[@]} -gt 0 ] && printf -v urlArgs ' --url %q' "${urls[@]}"
    local quotedFileAttributeArgs; [ ${#fileAttributeArgs[@]} -gt 0 ] && printf -v quotedFileAttributeArgs ' %q' "${fileAttributeArgs[@]}"

    local destination="${!#}"
    printf '%q ' "${fileAttributeArgs[@]}" -- "$destination"
    printf '\n%s -- %q\n' "file-download-installer${isBatch:+ --batch}${applicationName:+ --application-name }${applicationName} --expression ${fileGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}${quotedFileAttributeArgs}" "$destination"
}

typeset -A addedInstallUrlActions=()
typeset -a addedInstallUrlActionList=()
hasInstallUrl()
{
    local parse; parse="$(parseInstallUrl "${1:?}")" || exit 3
    local quotedFileAttributeArgs="${parse%%$'\n'*}"
    local fileDownloadInstallerCommand="${parse#*$'\n'}"

    [ "${addedInstallUrlActions["$fileDownloadInstallerCommand"]}" ] && return 0	# This install+url action has already been selected for installation.

    eval "hasFileAttributes $quotedFileAttributeArgs 2>/dev/null"   # Do both destination file existence check and attribute check with hasFileAttributes; suppress the "ERROR: FILE does not exist" for the former.
}

addInstallUrl()
{
    local parse; parse="$(parseInstallUrl "${1:?}")" || exit 3
    local fileDownloadInstallerCommand="${parse#*$'\n'}"

    # Note: Do not support pre-/postinstall hooks here (yet), as there's no good
    # short "name" that we could use. The DEST-FILE's whole path may be a bit
    # long, and just the filename itself may be ambiguous.
    addedInstallUrlActions["$fileDownloadInstallerCommand"]=t
    addedInstallUrlActionList+=("$fileDownloadInstallerCommand")
}
installInstallUrl()
{
    [ ${#addedInstallUrlActions[@]} -eq ${#addedInstallUrlActionList[@]} ] || { echo >&2 'ASSERT: InstallUrl actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedInstallUrlActionList[@]} -gt 0 ] || return

    toBeInstalledCommands+=("${addedInstallUrlActionList[@]}")
}

typeRegistry+=([install+url:]=InstallUrl)
typeInstallOrder+=([890]=InstallUrl)