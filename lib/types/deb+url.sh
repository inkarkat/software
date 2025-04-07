#!/bin/bash source-this-script

configUsageDebUrl()
{
    : ${INSTALL_REPO:=~/install}
    cat <<HELPTEXT
deb+url: items consist of a
    PACKAGE[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL [...]]
triplet / quadruplet.
If ${INSTALL_REPO}/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the *.deb
from URL(s) (first that succeeds) will be downloaded (and put into
${INSTALL_REPO}/* if it exists).
You can use %DEB_ARCH% to refer to the machine architecture in PACKAGE-GLOB and
URL.
If no URL is given and the package does not exist, the installation will fail.
For a dummy target, it's enough to specify PACKAGE:*
HELPTEXT
}

typeRegistry+=([deb+url:]=DebUrl)
typeInstallOrder+=([131]=DebUrl)

if ! exists dpkg; then
    hasDebUrl() { return 98; }
    installDebUrl() { :; }
    return
fi

typeset -A addedDebUrlRecords=()
hasAddedRecordWithTheSamePackageName()
{
    local testRecord="${1:?}"; shift
    local testPackageName="${testRecord%%:*}"
    local record; for record in "${addedDebUrlRecords[@]}"
    do
	[ "${record%%:*}" = "$testPackageName" ] && return 0
    done
    return 1
}
hasDebUrl()
{
    if [[ ! "$1" =~ ^[^:]+:.+: ]]; then
	printf >&2 'ERROR: Invalid deb+url item: "deb+url:%s"\n' "$1"
	exit 3
    fi

    hasApt "${1%%:*}" \
	|| [ "${addedDebUrlRecords["$1"]}" ] \
	|| hasAddedRecordWithTheSamePackageName "$1"
}

addDebUrl()
{
    local debUrlRecord="${1:?}"; shift
    local packageName="${debUrlRecord%%:*}"

    preinstallHook DebUrl "$packageName"
    addedDebUrlRecords["$debUrlRecord"]=t
    externallyAddedAptPackages["$packageName"]=t
    postinstallHook DebUrl "$packageName"
}

isAvailableDebUrl()
{
    isQuiet=t hasDebUrl "$@"
}

installDebUrl()
{
    [ ${#addedDebUrlRecords[@]} -gt 0 ] || return
    local debUrlRecord; for debUrlRecord in "${!addedDebUrlRecords[@]}"
    do
	local maxAge=
	local applicationNamePackageGlobUrl="${debUrlRecord#*:}"
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
	    "deb-download-installer${isBatch:+ --batch}${applicationName:+ --application-name }${applicationName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}" \
	    "${decoration["deb+url:$debUrlRecord"]}"
    done
}
