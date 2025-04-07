#!/bin/bash source-this-script

_setup_software_complete()
{
    local softwareDefinitionsDirspec="${1:?}"; shift
    local IFS=$'\n'
    COMPREPLY=()
    local cur="${COMP_WORDS[COMP_CWORD]}"

    readarray -t COMPREPLY < <(
	cd "$softwareDefinitionsDirspec" \
	    && readarray -t files < <(find . -type f -name .groupdir-description -prune -o -name .groupdir-filter -prune -o -printf '%P\n') \
	    && compgen -W "${files[*]}" -- "$cur"
    )
    [ ${#COMPREPLY[@]} -gt 0 ] && readarray -t COMPREPLY < <(printf "%q\n" "${COMPREPLY[@]}")
}

# Usage:
#_setup_TODO_software_complete()
#{
#    _setup_software_complete /path/to/TODO-software/etc/definitions "$@"
#}
#complete -F _setup_TODO_software_complete setup-TODO-software
