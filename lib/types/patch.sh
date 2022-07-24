#!/bin/bash source-this-script

configUsagePatchFile()
{
    cat <<HELPTEXT
patch: items consist of addPatch arguments
    [--sudo] [--no-backup|--no-subsequent-backup|--backup|--backup-command writeorig|writebackup|writeOrigOrBackup] [--backup-dir|-d DIR [--create-backup-dir]] [--on-update-command COMMANDLINE [--on-update-command ...]] [--on-up-to-date-command COMMANDLINE [--on-up-to-date-command ...]] [--first|--all] [PATCH-ARGS ...] [--] PATCH-FILE [...]
or just
    PATCH-FILE [...]
PATCH-FILE(s) are either relative to the ./etc/files directory tree, or an
absolute filespec.
HELPTEXT
}

convertFilesToAbsolute()
{
    # PATCH(es) may be 1 or more existing filespecs at the end, up to an
    # optional --.
    local patchRecord="${1:?}"; shift
    eval "set -- $patchRecord"
    typeset -a patchFilespecs=()
    local i filespec
    for ((i = $#; i > 0; i--))
    do
	if [ "${*:$i:1}" = '--' ]; then
	    break
	elif filespec="$(getAbsoluteOrFilesFilespec "${*:$i:1}")"; then
	    patchFilespecs=("$filespec" "${patchFilespecs[@]}")
	else
	    break
	fi
    done

    if [ ${#patchFilespecs[@]} -eq 0 ]; then
	printf >&2 'ERROR: Invalid patch item: "patch:%s" due to missing PATCH-FILE.\n' "$patchRecord"
	return 3
    fi

    printf '%q ' "${@:1:$i}" "${patchFilespecs[@]}"
}

# Note: Use both dict and list to maintain the original ordering in the
# definition(s), which may (rarely) be important.
typeset -A addedPatchActions=()
typeset -a addedPatchActionList=()
hasPatchFile()
{
    local patchRecord; patchRecord="$(convertFilesToAbsolute "${1:?}")" || exit $?

    [ "${addedPatchActions["$patchRecord"]}" ] && return 0	# This patch action has already been selected for installation.

    local decoration="${decoration["patch:$patchRecord"]}"
    eval "$(decorateCommand "addPatch --check $patchRecord" "$decoration")"
}

addPatchFile()
{
    local patchRecord; patchRecord="$(convertFilesToAbsolute "${1:?}")" || exit $?

    # Note: Do not support pre-/postinstall hooks here (yet), as there's no good
    # short "name" that we could use. The PATCH's whole path may be a bit long,
    # and just the filename itself may be ambiguous.
    addedPatchActions["$patchRecord"]=t
    addedPatchActionList+=("$patchRecord")
}
installPatchFile()
{
    [ ${#addedPatchActions[@]} -eq ${#addedPatchActionList[@]} ] || { echo >&2 'ASSERT: Patch actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedPatchActionList[@]} -gt 0 ] || return

    local patchRecord; for patchRecord in "${addedPatchActionList[@]}"
    do
	submitInstallCommand "addPatch $patchRecord" "${decoration["patch:$patchRecord"]}"
    done
}

typeRegistry+=([patch:]=PatchFile)  # Note: The type is named "PatchFile" to avoid a clash of the internal function with the external addPatch command.
typeInstallOrder+=([881]=PatchFile)
