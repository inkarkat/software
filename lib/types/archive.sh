#!/bin/bash source-this-script

configUsageArchive()
{
    local prefix="${1:?}"; shift
    cat <<HELPTEXT
${prefix}: items consist of
    [${prefix^^}-ARGS ...] SOURCE-ARCHIVE /PATH/TO[/.[.[.]]]/DESTINATION
SOURCE-ARCHIVE is a $prefix archive either relative to the ./etc/files directory
tree, or an absolute filespec and is extracted to DESTINATION unless that
already is up-to-date.
If /PATH/TO/./DESTINATION contains a ..././... path element, /PATH/TO will be
passed to tar as the extraction directory (to handle archives that contain
relative subpaths and assume a certain installation base directory).
Each additional . in .../.[.[.]]/... will strip one leading path component from
the archive.
A missing path to DESTINATION is created automatically.
HELPTEXT
}
configUsageTar()
{
    configUsageArchive tar "$@"
}
configUsageZip()
{
    configUsageArchive zip "$@"
}

typeset -A addedTarPackages=()
typeset -A addedZipPackages=()
resolveArchiveSourceFilespec()
{
    local prefix="${1:?}"; shift
    local archiveItem="${1:?}"; shift
    eval "set -- $archiveItem" || return 3
    if [ $# -lt 2 ]; then
	printf >&2 'ERROR: Invalid %s item: "%s:%s"; missing argument.\n' "$prefix" "$prefix" "$archiveItem"
	return 3
    fi
    local sourceFilespec; if ! sourceFilespec="$(getAbsoluteOrFilesFilespec "${*:(-2):1}")"; then
	printf >&2 'ERROR: Invalid %s item: "%s:%s" due to missing SOURCE-ARCHIVE: "%s".\n' "$prefix" "$prefix" "$archiveRecord" "${*:(-2):1}"
	return 3
    fi
    printf %s "$sourceFilespec"
}
resolveArchiveDestinationFilespec()
{
    local prefix="${1:?}"; shift
    local archiveItem="${1:?}"; shift
    eval "set -- $archiveItem" || return 3
    if [ $# -lt 2 ]; then
	printf >&2 'ERROR: Invalid %s item: "%s:%s"; missing argument.\n' "$prefix" "$prefix" "$archiveItem"
	return 3
    fi

    local destinationFilespec="${!#}"
    if [[ "$destinationFilespec" =~ ^(.*)/(\.+)(/.*)?$ ]]; then
	local destinationBaseDirspec="${BASH_REMATCH[1]}"
	local destinationPath="${BASH_REMATCH[3]}"
	local i stripPathComponentsCount=$((${#BASH_REMATCH[2]} - 1))
	for ((i = 0; i < stripPathComponentsCount; i++))
	do
	    destinationPath="/${destinationPath#/*/}"
	done
	destinationFilespec="${destinationBaseDirspec}${destinationPath}"
    fi
    printf %s "$destinationFilespec"
}
hasArchive()
{
    local prefix="${1:?}"; shift
    local archivePackagesDictName="${1:?}"; shift
    local archiveRecord="${1:?}"
    local destinationFilespec; destinationFilespec="$(resolveArchiveDestinationFilespec "$prefix" "$archiveRecord")" || exit $?
    local -n archivePackages=$archivePackagesDictName
    [ -e "$destinationFilespec" ] || [ "${archivePackages["$archiveRecord"]}" ]
}
hasTar()
{
    hasArchive tar addedTarPackages "$@"
}
hasZip()
{
    hasArchive zip addedZipPackages "$@"
}

addArchive()
{
    local prefix="${1:?}"; shift
    local archivePackagesDictName="${1:?}"; shift
    local archiveRecord="${1:?}"; shift
    local destinationFilespec; destinationFilespec="$(resolveArchiveDestinationFilespec "$prefix" "$archiveRecord")" || exit $?
    local packageName="$(basename -- "$destinationFilespec")"

    preinstallHook "$packageName"
    local -n archivePackages=$archivePackagesDictName
    archivePackages["$archiveRecord"]=t
    postinstallHook "$packageName"
}
addTar()
{
    addArchive tar addedTarPackages "$@"
}
addZip()
{
    addArchive zip addedZipPackages "$@"
}

installArchive()
{
    local prefix="${1:?}"; shift
    local unarchiveCommand="${1:?}"; shift
    local unarchiveDestinationDirArgName="${1:?}"; shift
    local archivePackagesDictName="${1:?}"; shift
    local -n archivePackages=$archivePackagesDictName
    [ ${#archivePackages[@]} -gt 0 ] || return

    local archiveRecord; for archiveRecord in "${!archivePackages[@]}"
    do
	eval "set -- ${archiveRecord:?}" || exit 3
	local sourceFilespec; sourceFilespec="$(resolveArchiveSourceFilespec "$prefix" "$archiveRecord")" || exit $?
	local quotedSourceFilespec; printf -v quotedSourceFilespec %q "$sourceFilespec"
	local destinationFilespec="${!#}"

	local extractionDirspecCreationCommand=
	local quotedExtractionDirspec=
	local isSudo=
	typeset -a additionalArchiveArgs=(); [ $# -ge 2 ] && additionalArchiveArgs=("${@:1:$(($#-2))}")
	if [[ "$destinationFilespec" =~ ^(.*)/(\.+)(/.*)?$ ]]; then
	    local extractionDirspec="${BASH_REMATCH[1]}"
	    local stripPathComponentsCount=$((${#BASH_REMATCH[2]} - 1))
	    printf -v quotedExtractionDirspec %q "$extractionDirspec"
	    if [ -d "$extractionDirspec" ]; then
		[ -w "$extractionDirspec" ] || isSudo=t
	    else
		extractionDirspecCreationCommand="${SUDO}${SUDO:+ }mkdir --parents -- $quotedExtractionDirspec && "
		isSudo=t
	    fi
	    [ $stripPathComponentsCount -eq 0 ] || additionalArchiveArgs+=("--strip-components=$stripPathComponentsCount")
	fi
	local quotedAdditionalArchiveArgs=; [ ${#additionalArchiveArgs[@]} -eq 0 ] || printf -v quotedAdditionalArchiveArgs ' %q' "${additionalArchiveArgs[@]}"

	submitInstallCommand \
	    "${extractionDirspecCreationCommand}${isSudo:+${SUDO}${SUDO:+ }}${unarchiveCommand} ${quotedSourceFilespec}${quotedAdditionalArchiveArgs}${quotedExtractionDirspec:+ $unarchiveDestinationDirArgName $quotedExtractionDirspec}" \
	    "${decoration["${prefix}:$archiveRecord"]}"
    done
}
installTar()
{
    installArchive tar 'tar --no-same-owner -xf' '--directory' addedTarPackages "$@"
}
installZip()
{
    installArchive zip 'unzip' '-d' addedZipPackages "$@"
}

typeRegistry+=([tar:]=Tar)
typeRegistry+=([zip:]=Zip)
typeInstallOrder+=([400]=Tar)
typeInstallOrder+=([401]=Zip)
