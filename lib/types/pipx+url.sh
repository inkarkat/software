#!/bin/bash source-this-script

configUsagePipxUrl()
{
    cat <<HELPTEXT
pipx+url: items consist of a
    PACKAGE-NAME[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL [...]]
triplet / quadruplet.
If ${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the tar
archive from URL(s) (first that succeeds) will be downloaded (and put into
${INSTALL_REPO}/* if it exists).
If no URL is given and the package does not exist, the installation will fail.
For a dummy target, it's enough to specify PACKAGE-NAME:*:
HELPTEXT
}

typeset -A addedPipxUrlRecords=()
hasPipxUrl()
{
    if [[ ! "$1" =~ ^[^:]+:.+: ]]; then
	printf >&2 'ERROR: Invalid pipx+url item: "pipx+url:%s"\n' "$1"
	exit 3
    fi

    hasPipx "${1%%:*}" || [ "${addedPipxUrlRecords["$1"]}" ]
}

addPipxUrl()
{
    local pipxUrlRecord="${1:?}"; shift
    local pipxPackageName="${pipxUrlRecord%%:*}"

    isAvailableOrUserAcceptsGroup pipx "${projectDir}/lib/definitions/pipx" 'pipx Python 3 package manager' || return $?

    preinstallHook "$pipxPackageName"
    addedPipxUrlRecords["$pipxUrlRecord"]=t
    externallyAddedPipxPackages["$pipxPackageName"]=t
    postinstallHook "$pipxPackageName"
}

isAvailablePipxUrl()
{
    isQuiet=t hasPipxUrl "$@"
}

installPipxUrl()
{
    [ ${#addedPipxUrlRecords[@]} -gt 0 ] || return

    local pipxUrlRecord; for pipxUrlRecord in "${!addedPipxUrlRecords[@]}"
    do
	local maxAge=
	local applicationNamePackageGlobUrl="${pipxUrlRecord#*:}"
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

	# Note: No sudo here, as the downloading will happen as the current user
	# and only the installation itself will be done through sudo.
	submitInstallCommand \
	    "pipx-download-installer --global${isBatch:+ --batch}${applicationName:+ --application-name }${applicationName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}" \
	    "${decoration["pipx+url:$pipxUrlRecord"]}"
    done
}

typeRegistry+=([pipx+url:]=PipxUrl)
typeInstallOrder+=([306]=PipxUrl)
