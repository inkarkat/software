#!/bin/bash source-this-script

configUsageTarUrl()
{
    : ${INSTALL_REPO:=~/install}
    cat <<HELPTEXT
tar+url: items consist of a
    /PATH/TO[/.[.[.]]]/DESTINATION[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL [...]]
triplet / quadruplet.
If /PATH/TO/DESTINATION does not yet exist, the tape or disk archive will be
downloaded and extracted to create it.
If ${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the tape or
disk archive from URL(s) (first that succeeds) will be downloaded (and put into
${INSTALL_REPO}/* if it exists), and then extracted.
If /PATH/TO/./DESTINATION contains a ..././... path element, /PATH/TO will be
passed to tar as the extraction directory (to handle archives that contain
relative subpaths and assume a certain installation base directory).
Each additional . in .../.[.[.]]/... will strip one leading path component from
the archive.
If no URL is given and the package does not exist, the installation will fail.
HELPTEXT
}
configUsageZipUrl()
{
    : ${INSTALL_REPO:=~/install}
    cat <<HELPTEXT
zip+url: items consist of a
    /PATH/TO[/.]/DESTINATION[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL [...]]
triplet / quadruplet.
If /PATH/TO/DESTINATION does not yet exist, the ZIP archive will be downloaded
and extracted to create it.
If ${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the *.zip
from URL(s) (first that succeeds) will be downloaded (and put into
${INSTALL_REPO}/* if it exists), and then extracted.
If /PATH/TO/./DESTINATION contains a ..././... path element, /PATH/TO will be
passed to zip as the extraction directory (to handle archives that contain
relative subpaths and assume a certain installation base directory).
If no URL is given and the package does not exist, the installation will fail.
HELPTEXT
}

typeset -A addedTarUrlPackages=()
typeset -A addedZipUrlPackages=()
resolveArchiveUrlDestinationFilespec()
{
    local destinationFilespec="${1:?}"; shift
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
hasArchiveUrl()
{
    local archiveUrlPackagesDictName="added${1:?}Packages"; shift
    local archiveUrlRecord="${1:?}"; shift
    local destinationFilespec="$(resolveArchiveUrlDestinationFilespec "${archiveUrlRecord%%:*}")"
    [ -e "$destinationFilespec" ] || eval "[ \"\${${archiveUrlPackagesDictName}[\"\$archiveUrlRecord\"]}\" ]"
}
hasTarUrl()
{
    hasArchiveUrl TarUrl "$@"
}
hasZipUrl()
{
    hasArchiveUrl ZipUrl "$@"
}

addArchiveUrl()
{
    local typeName="${1:?}"; shift; local archiveUrlPackagesDictName="added${typeName}Packages"
    local archiveUrlRecord="${1:?}"; shift
    local destinationFilespec="$(resolveArchiveUrlDestinationFilespec "${archiveUrlRecord%%:*}")"
    local packageName="$(basename -- "$destinationFilespec")"

    preinstallHook "$typeName" "$packageName"
    eval "${archiveUrlPackagesDictName}[\"\$archiveUrlRecord\"]=t"
    postinstallHook "$typeName" "$packageName"
}
addTarUrl()
{
    addArchiveUrl TarUrl "$@"
}
addZipUrl()
{
    addArchiveUrl ZipUrl "$@"
}

installArchiveUrl()
{
    local prefix="${1:?}"; shift
    local archiveDownloadInstallerCommand="${1:?}"; shift
    local archiveUrlPackagesDictName="added${1:?}Packages"; shift
    eval "[ \${#${archiveUrlPackagesDictName}[@]} -gt 0 ]" || return
    eval "typeset -a addedArchiveUrlRecords=(\"\${!${archiveUrlPackagesDictName}[@]}\")"
    local archiveUrlRecord; for archiveUrlRecord in "${addedArchiveUrlRecords[@]}"
    do
	typeset -a additionalArchiveArgs=()
	local destinationFilespec="${archiveUrlRecord%%:*}"
	local extractionDirspecCreationCommand=
	local quotedExtractionDirspec='.'
	typeset -a archiveDownloadInstallerArgs=()
	if [[ "$destinationFilespec" =~ ^(.*)/(\.+)(/.*)?$ ]]; then
	    local extractionDirspec="${BASH_REMATCH[1]}"
	    local stripPathComponentsCount=$((${#BASH_REMATCH[2]} - 1))
	    printf -v quotedExtractionDirspec %q "$extractionDirspec"
	    if [ -d "$extractionDirspec" ]; then
		[ -w "$extractionDirspec" ] || archiveDownloadInstallerArgs+=(--sudo)
	    else
		extractionDirspecCreationCommand="${SUDO}${SUDO:+ }mkdir --parents -- $quotedExtractionDirspec && "
		[ -z "$SUDO" ] || archiveDownloadInstallerArgs+=(--sudo)
	    fi
	    [ $stripPathComponentsCount -eq 0 ] || additionalArchiveArgs+=("--strip-components=$stripPathComponentsCount")
	fi
	local quotedAdditionalArchiveArgs=; [ ${#additionalArchiveArgs[@]} -eq 0 ] || printf -v quotedAdditionalArchiveArgs ' %q' "${additionalArchiveArgs[@]}"
	local maxAge=
	local applicationNamePackageGlobUrl="${archiveUrlRecord#*:}"
	if [[ "$applicationNamePackageGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	    maxAge="${BASH_REMATCH[0]%:}"
	    applicationNamePackageGlobUrl="${applicationNamePackageGlobUrl#"${BASH_REMATCH[0]}"}"
	fi
	local urlList="${applicationNamePackageGlobUrl#*:}"
	local applicationNameAndPackageGlob="${applicationNamePackageGlobUrl%:$urlList}"
	local packageGlob="${applicationNameAndPackageGlob##*/}"
	local applicationName="${applicationNameAndPackageGlob%"$packageGlob"}"
	local outputNameArg=; isglob "$packageGlob" || printf -v outputNameArg %q "$packageGlob"
	printf -v packageGlob %q "$packageGlob"
	applicationName="${applicationName%/}"
	printf -v applicationName %q "$applicationName"
	typeset -a urls=(); IFS=' ' read -r -a urls <<<"$urlList"
	local urlArgs=''; [ ${#urls[@]} -gt 0 ] && printf -v urlArgs ' --url %q' "${urls[@]}"

	submitInstallCommand \
	    "${extractionDirspecCreationCommand}${archiveDownloadInstallerCommand}${quotedAdditionalArchiveArgs}${isBatch:+ --batch}${archiveDownloadInstallerArgs:+ }${archiveDownloadInstallerArgs[*]} --destination-dir ${quotedExtractionDirspec}${applicationName:+ --application-name }${applicationName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}" \
	    "${decoration["${prefix}:$archiveUrlRecord"]}"
    done
}
installTarUrl()
{
    installArchiveUrl tar+url 'tar-download-installer --no-same-owner' TarUrl "$@"
}
installZipUrl()
{
    installArchiveUrl zip+url zip-download-installer ZipUrl "$@"
}

typeRegistry+=([tar+url:]=TarUrl)
typeRegistry+=([zip+url:]=ZipUrl)
typeInstallOrder+=([410]=TarUrl)
typeInstallOrder+=([411]=ZipUrl)
