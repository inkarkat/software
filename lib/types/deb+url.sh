#!/bin/bash source-this-script

configUsageDebUrl()
{
    cat <<'HELPTEXT'
deb+url: items consist of a
    PACKAGE[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL]
triplet / quadruplet.
If ~/install/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists [and if it is
younger than MAX-AGE[SUFFIX]], it will be used; else, the *.deb from URL will
be downloaded (and put into ~/install/* if it exists). If no URL is given and
the package does not exist, the installation will fail.
HELPTEXT
}

hasDebUrl()
{
    hasNative "${1%%:*}"
}

typeset -a addedDebUrlPackages=()
addDebUrl()
{
    addedDebUrlPackages+=("${1:?}")
}

installDebUrl()
{
    [ ${#addedDebUrlPackages[@]} -gt 0 ] || return
    local debUrlRecord; for debUrlRecord in "${addedDebUrlPackages[@]}"
    do
	local maxAge=
	local packageNameGlobUrl="${debUrlRecord#*:}"
	if [[ "$packageNameGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	    maxAge="${BASH_REMATCH[0]%:}"
	    packageNameGlobUrl="${packageNameGlobUrl#"${BASH_REMATCH[0]}"}"
	fi
	local packageUrl="${packageNameGlobUrl#*:}"
	local packageNameAndGlob="${packageNameGlobUrl%:$packageUrl}"
	local packageGlob="${packageNameAndGlob##*/}"
	local packageName="${packageNameAndGlob%"$packageGlob"}"
	packageName="${packageName%/}"

	# Note: No sudo here, as the downloading will happen as the current user
	# and only the installation itself will be done through sudo.
	toBeInstalledCommands+=("deb-download-installer${packageName:+ --application-name "'"}${packageName}${packageName:+"'"} --expression '$packageGlob'${maxAge:+ --max-age }$maxAge --url '$packageUrl'")
    done
}

typeRegistry+=([deb+url:]=DebUrl)
typeInstallOrder+=([30]=DebUrl)
