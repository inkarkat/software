#!/bin/bash source-this-script

configUsageWine()
{
    cat <<'HELPTEXT'
wine+url: items consist of a
    EXECUTABLE-NAME?[:MAX-AGE[SUFFIX]]:[[SUBDIR/]NAME/]PACKAGE-GLOB:[URL]
triplet / quadruplet.
If EXECUTABLE-NAME? (located in Wine's drive C: unless it's an absolute path)
exists / resolves to an existing file or directory, the item is deemed already
installed.
Else if ~/install/(SUBDIR|*)/(NAME|*)/PACKAGE-GLOB already exists [and if it is
younger than MAX-AGE[SUFFIX]], it will be used; else, the *.exe / *.msi from URL
will be downloaded (and put into ~/install/* if it exists). If no URL is given
and the package does not exist, the installation will fail.
HELPTEXT
}

typeset -A addedWineUrlPackages=()
hasWine()
{
    if [[ ! "$1" =~ ^[^:]+\?:.+: ]]; then
	printf >&2 'ERROR: Invalid wine+url item: "wine+url:%s"\n' "$1"
	exit 3
    fi
    local checkGlob="${1%%:*}"

    [ "${addedWineUrlPackages["$1"]}" ] && return 0	# This package has already been selected for installation.

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
    local packageNameGlobUrl="${wineUrlRecord#*:}"
    if [[ "$packageNameGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	packageNameGlobUrl="${packageNameGlobUrl#"${BASH_REMATCH[0]}"}"
    fi
    local packageUrl="${packageNameGlobUrl#*:}"
    local packageNameAndGlob="${packageNameGlobUrl%:$packageUrl}"
    local packageGlob="${packageNameAndGlob##*/}"
    local packageName="${packageNameAndGlob%"$packageGlob"}"
    packageName="${packageName%/}"
    packageOnlyName="${packageName##*/}"

    [ -z "$packageOnlyName" ] || preinstallHook "$packageOnlyName"
    addedWineUrlPackages["$wineUrlRecord"]=t
    [ -z "$packageOnlyName" ] || postinstallHook "$packageOnlyName"
}

isAvailableWine()
{
    local executableNameAndPackageName="${1:?}"; shift
    local queriedExecutableName="${executableNameAndPackageName%%:*}"; shift
    local queriedPackageName="${executableNameAndPackageName#"${queriedExecutableName}:"}"; shift


    hasWine "${queriedExecutableName}:${queriedPackageName}:" && return 0

    local wineUrlRecord; for wineUrlRecord in "${!addedWineUrlPackages[@]}"
    do
	local packageNameGlobUrl="${wineUrlRecord#*:}"
	if [[ "$packageNameGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	    packageNameGlobUrl="${packageNameGlobUrl#"${BASH_REMATCH[0]}"}"
	fi
	local packageUrl="${packageNameGlobUrl#*:}"
	local packageNameAndGlob="${packageNameGlobUrl%:$packageUrl}"
	local packageGlob="${packageNameAndGlob##*/}"
	local packageName="${packageNameAndGlob%"$packageGlob"}"
	packageName="${packageName%/}"

	[ "$packageName" = "$queriedPackageName" ] && return 0
    done

    return 1
}

installWine()
{
    [ ${#addedWineUrlPackages[@]} -gt 0 ] || return
    local wineUrlRecord; for wineUrlRecord in "${!addedWineUrlPackages[@]}"
    do
	local maxAge=
	local packageNameGlobUrl="${wineUrlRecord#*:}"
	if [[ "$packageNameGlobUrl" =~ ^[0-9]+([smhdwyg]|mo): ]]; then
	    maxAge="${BASH_REMATCH[0]%:}"
	    packageNameGlobUrl="${packageNameGlobUrl#"${BASH_REMATCH[0]}"}"
	fi
	local packageUrl="${packageNameGlobUrl#*:}"
	local packageNameAndGlob="${packageNameGlobUrl%:$packageUrl}"
	local packageGlob="${packageNameAndGlob##*/}"
	local packageName="${packageNameAndGlob%"$packageGlob"}"
	packageName="${packageName%/}"

	# Note: No sudo here, as downloading and installation will happen as the
	# current user.
	toBeInstalledCommands+=("wine-download-installer${packageName:+ --application-name "'"}${packageName}${packageName:+"'"} --expression '$packageGlob'${maxAge:+ --max-age }$maxAge${packageUrl:+ --url '$packageUrl'}")
    done
}

typeRegistry+=([wine+url:]=Wine)
typeInstallOrder+=([400]=Wine)
