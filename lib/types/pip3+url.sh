#!/bin/bash source-this-script

configUsagePip3Url()
{
    cat <<HELPTEXT
pip3+url: items consist of a
    PACKAGE[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL [...]]
triplet / quadruplet.
If ${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the tar
archive from URL(s) (first that succeeds) will be downloaded (and put into
${INSTALL_REPO}/* if it exists).
If no URL is given and the package does not exist, the installation will fail.
HELPTEXT
}

typeset -A addedPip3UrlRecords=()
hasPip3Url()
{
    if [[ ! "$1" =~ ^[^:]+:.+: ]]; then
	printf >&2 'ERROR: Invalid pip3+url item: "pip3+url:%s"\n' "$1"
	exit 3
    fi

    hasPip3 "${1%%:*}" || [ "${addedPip3UrlRecords["$1"]}" ]
}

addPip3Url()
{
    local pip3UrlRecord="${1:?}"; shift
    local pip3PackageName="${pip3UrlRecord%%:*}"

    isAvailableOrUserAcceptsNative pip3 python3-pip 'pip3 Python 3 package manager' || return $?

    preinstallHook "$pip3PackageName"
    addedPip3UrlRecords["$pip3UrlRecord"]=t
    externallyAddedPip3Packages["$pip3PackageName"]=t
    postinstallHook "$pip3PackageName"
}

installPip3Url()
{
    [ ${#addedPip3UrlRecords[@]} -gt 0 ] || return

    local pip3UrlRecord; for pip3UrlRecord in "${!addedPip3UrlRecords[@]}"
    do
	local maxAge=
	local applicationNamePackageGlobUrl="${pip3UrlRecord#*:}"
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
	    "pip3-download-installer${isBatch:+ --batch}${applicationName:+ --application-name }${applicationName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}" \
	    "${decoration["pip3+url:$pip3UrlRecord"]}"
    done
}

typeRegistry+=([pip3+url:]=Pip3Url)
typeInstallOrder+=([301]=Pip3Url)
