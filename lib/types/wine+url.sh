#!/bin/bash source-this-script

configUsageWine()
{
    cat <<'HELPTEXT'
wine+url: items consist of a
    EXECUTABLE-NAME?[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL [...]]
triplet / quadruplet.
If EXECUTABLE-NAME? (located in Wine's drive C: unless it's an absolute path)
exists / resolves to an existing file or directory, the item is deemed already
installed.
Else if ~/install/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists [and if it is
younger than MAX-AGE[SUFFIX]], it will be used; else, the *.exe / *.msi from
URL(s) (first that succeeds) will be downloaded (and put into ~/install/* if it
exists). If no URL is given and the package does not exist, the installation
will fail.
HELPTEXT
}

typeRegistry+=([wine+url:]=Wine)
typeInstallOrder+=([700]=Wine)

if ! "${projectDir:?}/etc/require/intel-architecture"; then
    hasWine()
    {
	messagePrintf >&2 'Note: Wine is not available on non-Intel architectures; skipping %s.\n' "$1"
	return 99
    }
    installWine() { :; }
    return
fi

typeset -A addedWineUrlPackages=()
typeset -A externallyAddedWineUrlPackages=()
hasWine()
{
    if [[ ! "$1" =~ ^[^:]+\?:.+: ]]; then
	printf >&2 'ERROR: Invalid wine+url item: "wine+url:%s"\n' "$1"
	exit 3
    fi

    local checkGlob="${1%%:*}"

    [ "${addedWineUrlPackages["$1"]}" ] && return 0	# This package has already been selected for installation.
    [ "${externallyAddedWineUrlPackages["$1"]}" ] && return 0

    local -r wineDriveC=~/.wine/drive_c
    if [[ ! "$checkGlob" =~ ^/ ]] && [ -d "$wineDriveC" ]; then
	which "${wineDriveC}/${checkGlob%\?}" >/dev/null 2>&1 || expandglob -- "${wineDriveC}/${checkGlob%\?}" >/dev/null 2>&1 && return 0
    fi
    which "${checkGlob%\?}" >/dev/null 2>&1 || expandglob -- "${checkGlob%\?}" >/dev/null 2>&1
}

addWine()
{
    local wineUrlRecord="${1:?}"; shift
    isAvailableOrUserAcceptsNative wine || return $?
    isAvailableOrUserAcceptsNative wine32 || return $?

    # The best identifier for pre-/postinstall hooks is the package name
    # (without any [SUBDIR/]); unfortunately, it is optional and hard to parse,
    # so most of the implementation is copied from installWine().
    local applicationNamePackageGlobUrl="${wineUrlRecord#*:}"
    if [[ "$applicationNamePackageGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	applicationNamePackageGlobUrl="${applicationNamePackageGlobUrl#"${BASH_REMATCH[0]}"}"
    fi
    local urlList="${applicationNamePackageGlobUrl#*:}"
    local applicationNameAndPackageGlob="${applicationNamePackageGlobUrl%:$urlList}"
    local packageGlob="${applicationNameAndPackageGlob##*/}"
    local applicationName="${applicationNameAndPackageGlob%"$packageGlob"}"
    applicationName="${applicationName%/}"
    appliationOnlyName="${applicationName##*/}"

    [ -z "$appliationOnlyName" ] || preinstallHook "$appliationOnlyName"
    addedWineUrlPackages["$wineUrlRecord"]=t
    [ -z "$appliationOnlyName" ] || postinstallHook "$appliationOnlyName"
}

isAvailableWine()
{
    local executableNameAndApplicationName="${1:?}"; shift
    local queriedExecutableName="${executableNameAndApplicationName%%:*}"; shift
    local queriedApplicationName="${executableNameAndApplicationName#"${queriedExecutableName}:"}"; shift


    hasWine "${queriedExecutableName}:${queriedApplicationName}:" && return 0

    local wineUrlRecord; for wineUrlRecord in "${!addedWineUrlPackages[@]}"
    do
	local applicationNamePackageGlobUrl="${wineUrlRecord#*:}"
	if [[ "$applicationNamePackageGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	    applicationNamePackageGlobUrl="${applicationNamePackageGlobUrl#"${BASH_REMATCH[0]}"}"
	fi
	local urlList="${applicationNamePackageGlobUrl#*:}"
	local applicationNameAndPackageGlob="${applicationNamePackageGlobUrl%:$urlList}"
	local packageGlob="${applicationNameAndPackageGlob##*/}"
	local applicationName="${applicationNameAndPackageGlob%"$packageGlob"}"
	applicationName="${applicationName%/}"

	[ "$applicationName" = "$queriedApplicationName" ] && return 0
    done

    return 1
}

installWine()
{
    [ ${#addedWineUrlPackages[@]} -gt 0 ] || return
    local wineUrlRecord; for wineUrlRecord in "${!addedWineUrlPackages[@]}"
    do
	local maxAge=
	local applicationNamePackageGlobUrl="${wineUrlRecord#*:}"
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

	# Note: No sudo here, as downloading and installation will happen as the
	# current user.
	submitInstallCommand \
	    "wine-download-installer${isBatch:+ --batch}${applicationName:+ --application-name }${applicationName} --expression ${packageGlob}${maxAge:+ --max-age }$maxAge${urlArgs}${outputNameArg:+ --output }${outputNameArg}" \
	    "${decoration["wine+url:$wineUrlRecord"]}"
    done
}
