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
    unset useversion
    unset versionrefpoint
    unset author
    unset buildtype
    unset copyroot
    unset extrafiles
    unset removelist
    unset section
    unset description
    unset depends
    unset builddeps
    unset conflicts
    unset replaces
    unset preinst
    unset postinst
    unset prerm
    unset postrm
    unset arch
    unset extraoptions
    
    builderversion="$(git rev-list HEAD --count)"
}

runbuild()
{
    bash build.sh "$name" \
                  "$srcname" \
                  "$path" \
                  "$pjtdir" \
                  "$vcs" \
                  "$baseversion" \
                  "$version" \
                  "$useversion" \
                  "$builderversion" \
                  "$versionrefpoint" \
                  "$author" \
                  "$buildtype" \
                  "$copyroot" \
                  "$extrafiles" \
                  "$removelist" \
                  "$section" \
                  "$description" \
                  "$depends" \
                  "$builddeps" \
                  "$conflicts" \
                  "$replaces" \
                  "$preinst" \
                  "$postinst" \
                  "$prerm" \
                  "$postrm" \
                  "$arch" \
                  "$extraoptions"
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
        'useversion') useversion="${val}" ;;
        'builderversion') builderversion="${val}" ;;
        'versionrefpoint') versionrefpoint="${val}" ;;
        'author') author="${val}" ;;
        'build') buildtype="${val}" ;;
        'copyroot') copyroot="${val}" ;;
        'extrafiles') extrafiles="${val}" ;;
        'removelist') removelist="${val}" ;;
        'section') section="${val}" ;;
        'description') description="${val}" ;;
        'depends') depends="${val}" ;;
        'builddeps') builddeps="${val}" ;;
        'conflicts') conflicts="${val}" ;;
        'replaces') replaces="${val}" ;;
        'preinst') preinst="${val}" ;;
        'postinst') postinst="${val}" ;;
        'prerm') prerm="${val}" ;;
        'postrm') postrm="${val}" ;;
        'arch') arch="${val}" ;;
        'extra') extraoptions="${val}" ;;
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

