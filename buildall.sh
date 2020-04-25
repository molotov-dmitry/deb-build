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
    unset baseversion
    unset version
    unset author
    unset buildtype
    unset copyroot
    unset extrafiles
    unset section
    unset description
    unset depends
    unset preinst
    unset postinst
    unset prerm
    unset postrm
    
    builderversion="$(git log --pretty=format:'%h' | wc -w)"
}

runbuild()
{
    bash build.sh "$name" "$srcname" "$path" "${pjtdir}" "$vcs" "$baseversion" "$version" "$builderversion" "$author" "$buildtype" "$copyroot" "$extrafiles" "$section" "$description" "$depends" "$preinst" "$postinst" "$prerm" "$postrm"
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
        'baseversion') baseversion="${val}" ;;
        'version') version="${val}" ;;
        'builderversion') builderversion="${val}" ;;
        'author') author="${val}" ;;
        'build') buildtype="${val}" ;;
        'copyroot') copyroot="${val}" ;;
        'extrafiles') extrafiles="${val}" ;;
        'section') section="${val}" ;;
        'description') description="${val}" ;;
        'depends') depends="${val}" ;;
        'preinst') preinst="${val}" ;;
        'postinst') postinst="${val}" ;;
        'prerm') prerm="${val}" ;;
        'postrm') postrm="${val}" ;;
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

