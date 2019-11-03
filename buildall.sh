#!/bin/bash

set -e

ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT_PATH}"

reset()
{
    unset name
    unset path
    unset pjtdir
    unset srcname
    unset vcs
    unset version
    unset author
    unset buildtype
    unset section
    unset description
    unset depends
}

runbuild()
{
    bash build.sh "$name" "$srcname" "$path" "${pjtdir}" "$vcs" "$version" "$author" "$buildtype" "$section" "$description" "$depends"
}

getkey()
{
    echo "$@" | cut -s -d '=' -f 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

getval()
{
    echo "$@" | cut -s -d '=' -f 2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

array_contains()
{
    local seeking="$1"
    shift
    
    for element
    do
        if [[ "$element" == "$seeking" ]]
        then
            return 0
        fi
    done
    
    return 1
}

list="$1"

shift

reset

while read line
do

    if [[ -z "${line}" ]]
    then
        continue
    fi 

    if [[ "${line:0:1}" == '[' && "${line: -1}" == ']' ]]
    then
        if [[ -n "$name" ]] && ( [[ $# -eq 0 ]] || array_contains "$name" "$@" )
        then
            runbuild
        fi
        
        reset
        
        name=${line:1:-1}
        
    else
        key="$(getkey "${line}")"
        val="$(getval "${line}")"
        
        if [[ -z "${key}" ]]
        then
            echo "Unknown line: '${line}'" >&2
            false
        fi
        
        case "${key,,}" in
        'path') path="${val}" ;;
        'dir') pjtdir="${val}" ;;
        'source') srcname="${val}" ;;
        'vcs') vcs="${val}" ;;
        'version') version="${val}" ;;
        'author') author="${val}" ;;
        'build') buildtype="${val}" ;;
        'section') section="${val}" ;;
        'description') description="${val}" ;;
        'depends') depends="${val}" ;;
        *) 
            echo "Unknown config key: '${key}'" >&2
            false
        ;;
        esac
        
    fi

done < "${list}"

if [[ -n "$name" ]] && ( [[ $# -eq 0 ]] || array_contains "$name" "$@" )
then
    runbuild
fi

