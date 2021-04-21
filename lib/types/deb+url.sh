#!/bin/bash source-this-script

configUsageDebUrl()
{
    : ${INSTALL_DIR:=~/install}
    cat <<HELPTEXT
deb+url: items consist of a
    PACKAGE[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL [...]]
triplet / quadruplet.
If ${INSTALL_DIR}/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists
[and if it is younger than MAX-AGE[SUFFIX]], it will be used; else, the *.deb
from URL(s) (first that succeeds) will be downloaded (and put into
${INSTALL_DIR}/* if it exists).
If no URL is given and the package does not exist, the installation will fail.
HELPTEXT
}

typeRegistry+=([deb+url:]=DebUrl)
typeInstallOrder+=([131]=DebUrl)

if ! exists dpkg; then
    hasDebUrl() { return 98; }
    installDebUrl() { :; }
    return
fi

typeset -A addedDebUrlPackages=()
hasDebUrl()
{
    hasApt "${1%%:*}" || [ "${addedDebUrlPackages["${1:?}"]}" ]
}

addDebUrl()
{
    local debUrlRecord="${1:?}"; shift
    local packageName="${debUrlRecord%%:*}"

    preinstallHook "$packageName"
    addedDebUrlPackages["$debUrlRecord"]=t
    externallyAddedAptPackages["$packageName"]=t
    postinstallHook "$packageName"
}

installDebUrl()
{
    [ ${#addedDebUrlPackages[@]} -gt 0 ] || return
    local debUrlRecord; for debUrlRecord in "${!addedDebUrlPackages[@]}"
    do
	local maxAge=
	local packageNameGlobUrl="${debUrlRecord#*:}"
	if [[ "$packageNameGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	    maxAge="${BASH_REMATCH[0]%:}"
	    packageNameGlobUrl="${packageNameGlobUrl#"${BASH_REMATCH[0]}"}"
	fi
	local packageUrlList="${packageNameGlobUrl#*:}"
	local packageNameAndGlob="${packageNameGlobUrl%:$packageUrlList}"
	local packageGlob="${packageNameAndGlob##*/}"
	local packageName="${packageNameAndGlob%"$packageGlob"}"
	local packageOutputNameArg=; isglob "$packageGlob" || printf -v packageOutputNameArg %q "$packageGlob"
	printf -v packageGlob %q "$packageGlob"
	packageName="${packageName%/}"
	printf -v packageName %q "$packageName"
	typeset -a packageUrls=(); IFS=' ' read -r -a packageUrls <<<"$packageUrlList"
	local packageUrlArgs; printf -v packageUrlArgs ' --url %q' "${packageUrls[@]}"

	# Note: No sudo here, as the downloading will happen as the current user
	# and only the installation itself will be done through sudo.
	toBeInstalledCommands+=("deb-download-installer${isBatch:+ --batch}${packageName:+ --application-name }${packageName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${packageUrlArgs}${packageOutputNameArg:+ --output }${packageOutputNameArg}")
    done
}
