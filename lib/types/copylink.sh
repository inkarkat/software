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
configUsageKopy()
{
    cat <<HELPTEXT
copy: items consist of
    [ADDCOPY-ARGS ...] SOURCE DEST
SOURCE is either relative to the ./etc/files directory tree, or an absolute
filespec and is copied to DEST unless the latter already exists.
You can specify additional symcopy arguments:
    --sudo		Do the copying with sudo unless already running as the
			superuser.
    --force|-f		Overwrite (individual files in) an existing DEST.
    --no-target-directory
			Treat DEST as a normal file.
A missing path to DEST is created automatically.
HELPTEXT
}

parseLink()
{
    local linkItem="${1:?}"; shift
    typeset -a linkArgs=("$@")
    eval "set -- $linkItem"

    while [ $# -ne 0 ]
    do
	case "$1" in
	    --sudo|--force|-f)
			linkArgs+=("$1"); shift;;

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

    printf '%q ' addSymlink --parents "${linkArgs[@]}" -- "$sourceFilespec"
    printf %q "$2"
}
parseKopy()
{
    local copyItem="${1:?}"; shift
    typeset -a copyArgs=("$@")
    eval "set -- $copyItem"

    while [ $# -ne 0 ]
    do
	case "$1" in
	    --sudo|--force|-f|--no-target-directory)
			copyArgs+=("$1"); shift;;

	    --)		shift; break;;
	    -*)		printf >&2 'ERROR: Invalid copy item: "copy:%s" due to invalid "%s".\n' "$copyItem" "$1"; exit 3;;
	    *)		break;;
	esac
    done
    if [ $# -ne 2 ]; then
	printf >&2 'ERROR: Invalid copy item: "copy:%s" due to missing SOURCE DEST.\n' "$copyItem"
	exit 3
    fi

    local sourceFilespec; if ! sourceFilespec="$(getAbsoluteOrFilesFilespec "$1")"; then
	printf >&2 'ERROR: Invalid copy item: "copy:%s" due to missing SOURCE: "%s".\n' "$copyItem" "$1"
	exit 3
    fi

    printf '%q ' addCopy --parents "${copyArgs[@]}" -- "$sourceFilespec"
    printf %q "$2"
}

typeset -A addedLinkActions=()
typeset -a addedLinkActionList=()
typeset -A addedKopyActions=()
typeset -a addedKopyActionList=()
hasLink()
{
    local linkRecord="${1:?}"
    local quotedCheckCommand; quotedCheckCommand="$(parseLink "$linkRecord" --check)" || exit 3
    local quotedLinkCommand; quotedLinkCommand="$(parseLink "$linkRecord" --accept-up-to-date)" || exit 3

    [ "${addedLinkActions["$quotedLinkCommand"]}" ] && return 0	# This link action has already been selected for linking.

    local decoration="${decoration["link:$linkRecord"]}"
    eval "$(decorateCommand "$quotedCheckCommand" "$decoration")"
}
hasKopy()
{
    local copyRecord="${1:?}"
    local quotedCheckCommand; quotedCheckCommand="$(parseKopy "$copyRecord" --check)" || exit 3
    local quotedKopyCommand; quotedKopyCommand="$(parseKopy "$copyRecord" --accept-up-to-date)" || exit 3

    [ "${addedKopyActions["$quotedKopyCommand"]}" ] && return 0	# This copy action has already been selected for copying.

    local decoration="${decoration["copy:$copyRecord"]}"
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
addKopy()
{
    local copyRecord="${1:?}"
    local quotedKopyCommand; quotedKopyCommand="$(parseKopy "$copyRecord" --accept-up-to-date)" || exit 3
    # Note: Do not support pre-/postinstall hooks here (yet), as there's no good
    # short "name" that we could use. The DEST's whole path may be a bit
    # long, and just the filename itself may be ambiguous.
    addedKopyActions["$quotedKopyCommand"]="$copyRecord"
    addedKopyActionList+=("$quotedKopyCommand")
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
installKopy()
{
    [ ${#addedKopyActions[@]} -eq ${#addedKopyActionList[@]} ] || { echo >&2 'ASSERT: Kopy actions dict and list sizes disagree.'; exit 3; }
    [ ${#addedKopyActionList[@]} -gt 0 ] || return

    local quotedKopyCommand; for quotedKopyCommand in "${addedKopyActionList[@]}"
    do
	submitInstallCommand "$quotedKopyCommand" "${decoration["copy:${addedKopyActions["$quotedKopyCommand"]}"]}"
    done
}

typeRegistry+=([link:]=Link)
typeInstallOrder+=([882]=Link)
typeRegistry+=([copy:]=Kopy)
typeInstallOrder+=([883]=Kopy)
