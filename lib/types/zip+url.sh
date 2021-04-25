#!/bin/bash source-this-script

configUsageZipUrl()
{
    : ${INSTALL_DIR:=~/install}
    cat <<HELPTEXT
zip+url: items consist of a
    /PATH/TO[/.]/DESTINATION[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL [...]]
triplet / quadruplet.
If /PATH/TO/DESTINATION does not yet exist, the ZIP archive will be downloaded
and extracted to create it.
If ${INSTALL_DIR}/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the *.zip
from URL(s) (first that succeeds) will be downloaded (and put into
${INSTALL_DIR}/* if it exists), and then extracted. If /PATH/TO/./DESTINATION
contains a ..././... path element, /PATH/TO will be passed to zip as the
extraction directory (to handle archives that contain relative subpaths and
assume a certain installation base directory).
If no URL is given and the package does not exist, the installation will fail.
HELPTEXT
}

typeset -A addedZipUrlPackages=()
hasZipUrl()
{
    local zipUrlRecord="${1:?}"; shift
    local destinationFilespec="${zipUrlRecord%%:*}"
    if [[ "$destinationFilespec" =~ ^(.*)/\.(/.*)?$ ]]; then
	destinationFilespec="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    fi

    [ -e "$destinationFilespec" ] || [ "${addedZipUrlPackages["$zipUrlRecord"]}" ]
}

addZipUrl()
{
    local zipUrlRecord="${1:?}"; shift
    local destinationFilespec="${zipUrlRecord%%:*}"
    if [[ "$destinationFilespec" =~ ^(.*)/\.(/.*)?$ ]]; then
	destinationFilespec="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    fi
    local packageName="$(basename -- "$destinationFilespec")"

    preinstallHook "$packageName"
    addedZipUrlPackages["$zipUrlRecord"]=t
    postinstallHook "$packageName"
}

installZipUrl()
{
    [ ${#addedZipUrlPackages[@]} -gt 0 ] || return
    local zipUrlRecord; for zipUrlRecord in "${!addedZipUrlPackages[@]}"
    do
	local destinationFilespec="${zipUrlRecord%%:*}"
	local extractionDirspecCreationCommand=
	local quotedExtractionDirspec='.'
	if [[ "$destinationFilespec" =~ ^(.*)/\.(/.*)?$ ]]; then
	    printf -v quotedExtractionDirspec %q "${BASH_REMATCH[1]}"
	    extractionDirspecCreationCommand="${SUDO}${SUDO:+ }mkdir --parents -- $quotedExtractionDirspec && "
	fi

	local maxAge=
	local applicationNamePackageGlobUrl="${zipUrlRecord#*:}"
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
	local urlArgs; printf -v urlArgs ' --url %q' "${urls[@]}"

	toBeInstalledCommands+=("${extractionDirspecCreationCommand}${SUDO}${SUDO:+ }zip-download-installer${isBatch:+ --batch} --destination-dir $quotedExtractionDirspec ${applicationName:+ --application-name }${applicationName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}")
    done
}

typeRegistry+=([zip+url:]=ZipUrl)
typeInstallOrder+=([400]=ZipUrl)
