#!/bin/bash source-this-script

configUsageUpdatecheck()
{
    cat <<'HELPTEXT'
updatecheck: items consist of one or more FILE(s), and another ITEM at the end.
ITEM will be forcibly installed if the stored checksum of one of the FILEs has
changed since the last installation (or if the FILE has never been installed).
FILE is either relative to the ./etc directory tree, or an absolute filespec.
HELPTEXT
}

updateCheckChecksum()
{
    local filespec="${1:?}"; shift
    local checksumOutput="$(md5sum "$filespec")"
    local checksum; read -r checksum rest <<<"$checksumOutput"
    if [ -z "$checksum" ]; then
	printf >&2 'ERROR: Empty checksum from %s.\n' md5sum
	return 3
    fi
    printf %s "$checksum"
}

hasUpdatecheck()
{
    local updatecheckRecord="${1:?}"; shift
    eval "set -- $updatecheckRecord"
    if [ $# -lt 2 ]; then
	printf >&2 'ERROR: Invalid updatecheck item; need at least one FILE and one ITEM: "updatecheck:%s"\n' "$updatecheckRecord"
	exit 3
    fi

    typeset -a files=("${@:1:$(($#-1))}")
    local file; for file in "${files[@]}"
    do
	local sourceFilespec; if ! sourceFilespec="$(getAbsoluteOrBaseFilespec '' "$file")"; then
	    printf >&2 'ERROR: Invalid updatecheck item: "updatecheck:%s" due to missing FILE: "%s".\n' "$updatecheckRecord" "$file"
	    exit 3
	fi

	local storedChecksum; storedChecksum="$(keyValueDatabase updatecheck --query "${sourceFilespec/$'\t'/ }" --columns '*')" || return 1
	local currentChecksum; currentChecksum="$(updateCheckChecksum "$sourceFilespec")" || exit $?
	[ "$currentChecksum" = "$storedChecksum" ] || return 1
    done
}

typeset -A updatecheckFileChecksums=()
addUpdatecheck()
{
    local updatecheckRecord="${1:?}"; shift
    eval "set -- $updatecheckRecord"
    local item="${!#}"
    addItems "$item"

    typeset -a files=("${@:1:$(($#-1))}")
    local file; for file in "${files[@]}"
    do
	local sourceFilespec; if ! sourceFilespec="$(getAbsoluteOrBaseFilespec '' "$file")"; then
	    printf >&2 'ERROR: Invalid updatecheck item: "updatecheck:%s" due to missing FILE: "%s".\n' "$updatecheckRecord" "$file"
	    exit 3
	fi

	local currentChecksum; currentChecksum="$(updateCheckChecksum "$sourceFilespec")" || exit $?
	updatecheckFileChecksums["$sourceFilespec"]="$currentChecksum"
    done
}

installUpdatecheck()
{
    [ ${#updatecheckFileChecksums[@]} -gt 0 ] || return

    local databaseUpdate; printf -v databaseUpdate %q "${scriptDir}/${scriptName}"
    local sourceFilespec; for sourceFilespec in "${!updatecheckFileChecksums[@]}"
    do
	local record; printf -v record '%q%q%q' "${sourceFilespec//$'\t'/ }" $'\t' "${updatecheckFileChecksums["$sourceFilespec"]}"
	submitInstallCommand \
	    "${databaseUpdate}${isVerbose:+ --verbose} --key-value-database updatecheck --update $record"
    done
}

typeRegistry+=([updatecheck:]=Updatecheck)
typeInstallOrder+=([1]=Updatecheck)
