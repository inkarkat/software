#!/bin/bash source-this-script

configUsageLink()
{
    cat <<HELPTEXT
link: items consist of
    [ADDSYMLINK-ARGS ...] FROM NEW-LINK
FROM is either relative to the ./etc/files directory tree, or an absolute
filespec and is linked to NEW-LINK unless the latter already exists.
You can specify additional symlink arguments:
    --sudo		Do the linking with sudo unless already running as the
			superuser.
    --force|-f		Overwrite an existing NEW-LINK if it is a regular file
			or a symlink pointing elsewhere.
A missing path to NEW-LINK is created automatically.
HELPTEXT
}

parseLink()
{
    local linkItem="${1:?}"; shift
    typeset -a commonArgs=("$@")
    eval "set -- $linkItem"

    typeset -a linkArgs=()
    while [ $# -ne 0 ]
    do
	case "$1" in
	    --sudo)	commonArgs+=("$1"); shift;;
	    --force|-f)	linkArgs+=("$1"); shift;;

	    --)		shift; break;;
	    -*)		printf >&2 'ERROR: Invalid link item: "link:%s" due to invalid "%s".\n' "$linkItem" "$1"; exit 3;;
	    *)		break;;
	esac
    done
    if [ $# -ne 2 ]; then
	printf >&2 'ERROR: Invalid link item: "link:%s" due to missing FROM NEW-LINK.\n' "$linkItem"
	exit 3
    fi

    local sourceFilespec; if ! sourceFilespec="$(getAbsoluteOrFilesFilespec "$1")"; then
	printf >&2 'ERROR: Invalid link item: "link:%s" due to missing FROM: "%s".\n' "$linkItem" "$1"
	exit 3
    fi

    printf '%q ' addDir "${commonArgs[@]}" --
    printf '%q && ' "$(dirname -- "$2")"
    printf '%q ' addSymlink "${commonArgs[@]}" "${linkArgs[@]}" -- "$sourceFilespec"
    printf %q "$2"
}

typeset -A addedLinkActions=()
typeset -a addedLinkActionList=()
hasLink()
{
    local linkRecord="${1:?}"
    local quotedCheckCommand; quotedCheckCommand="$(parseLink "$linkRecord" --check)" || exit 3
    local quotedLinkCommand; quotedLinkCommand="$(parseLink "$linkRecord" --accept-up-to-date)" || exit 3

    [ "${addedLinkActions["$quotedLinkCommand"]}" ] && return 0	# This link action has already been selected for linking.

    local decoration="${decoration["link:$linkRecord"]}"
    eval "$(decorateCommand "$quotedCheckCommand" "$decoration")"
}

addLink()
{
    local linkRecord="${1:?}"
    local quotedLinkCommand; quotedLinkCommand="$(parseLink "$linkRecord" --accept-up-to-date)" || exit 3
    # Note: Do not support pre-/postinstall hooks here (yet), as there's no good
    # short "name" that we could use. The NEW-LINK's whole path may be a bit
    # long, and just the filename itself may be ambiguous.
    addedLinkActions["$quotedLinkCommand"]="$linkRecord"
    addedLinkActionList+=("$quotedLinkCommand")
}
installLink()
{
    [ ${#addedLinkActions[@]} -eq ${#addedLinkActionList[@]} ] || { echo >&2 'ASSERT: Link actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedLinkActionList[@]} -gt 0 ] || return

    local quotedLinkCommand; for quotedLinkCommand in "${addedLinkActionList[@]}"
    do
	submitInstallCommand "$quotedLinkCommand" "${decoration["link:${addedLinkActions["$quotedLinkCommand"]}"]}"
    done
}

typeRegistry+=([link:]=Link)
typeInstallOrder+=([882]=Link)
