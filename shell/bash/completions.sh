#!/bin/bash source-this-script

_setup_software_complete()
{
    local softwareDefinitionsDirspec="${1:?}"; shift
    local IFS=$'\n'
    COMPREPLY=()
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local opts='--help -h -? --config-help -H --check --dry-run --print-types --print-definitions -P --print -p --execute -e --quiet -q --silence-no-definitions --verbose -v --force -f --yes -y --recall-current-only --recall-only --batch -b --select -s --base-dir --add-base-dir --name --all -a --group-recall-current-only --group-recall-only --clear-group-recall --clear-definition-recall --clear-selection-store --rebuild-selection-store'

    readarray -O ${#COMPREPLY[@]} -t COMPREPLY < <(compgen -W "${opts// /$'\n'}" -- "$cur")

    [ "$softwareDefinitionsDirspec" = /dev/null ] \
	|| readarray -O ${#COMPREPLY[@]} -t COMPREPLY < <(
	    cd "$softwareDefinitionsDirspec" \
		&& readarray -t files < <(find . -type f -name .groupdir-description -prune -o -name .groupdir-filter -prune -o -printf '%P\n') \
		&& compgen -W "${files[*]}" -- "$cur"
	)
    [ ${#COMPREPLY[@]} -gt 0 ] && readarray -t COMPREPLY < <(printf "%q\n" "${COMPREPLY[@]}")
}

_setup_software_itself_complete()
{
    _setup_software_complete /dev/null "$@"
}
complete -F _setup_software_itself_complete setup-software

_update_software_complete()
{
    local softwareDefinitionsDirspec="${1:?}"; shift
    local IFS=$'\n'
    local cur opts

    opts='--help -h -? --check --dry-run -q --quiet --silence-no-definitions -v --verbose -f --force -y --yes  -b --batch -s --select --base-dir --name  -P --print-definitions -p --print -e --execute'
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    readarray -t COMPREPLY < <(compgen -W "${opts// /$'\n'}" -- "$cur")
    [ ${#COMPREPLY[@]} -gt 0 ] && readarray -t COMPREPLY < <(printf "%q\n" "${COMPREPLY[@]}")
    return 0
}
complete -F _update_software_complete update_software

_update_software_itself_complete()
{
    _update_software_complete /dev/null "$@"
}
complete -F _update_software_itself_complete update-software


# Usage:
#_setup_TODO_software_complete()
#{
#    _setup_software_complete /path/to/TODO-software/etc/definitions "$@"
#}
#complete -F _setup_TODO_software_complete setup-TODO-software
#_update_TODO_software_complete()
#{
#    _update_software_complete /path/to/TODO-software/etc/definitions "$@"
#}
#complete -F _update_TODO_software_complete update-TODO-software
