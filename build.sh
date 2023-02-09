#!/bin/bash

set -e

ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"

#### Functions =================================================================

join_by()
{
    local separator="$1"
    shift
    
    while [[ $# -gt 0 ]]
    do
        echo -ne "$1"
        shift
        
        if [[ $# -gt 0 ]]
        then
            echo -ne "$separator"
        fi
    done
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

#### Arguments =================================================================

name="$1"
shift

srcname="$1"
shift

path="$1"
shift

pjtdir="$1"
shift

vcs="$1"
shift

baseversion="$1"
shift

version="$1"
shift

builderversion="$1"
shift

versionrefpoint="$1"
shift

author="$1"
shift

buildtype="$1"
shift

copyroot="$1"
shift

extrafiles="$1"
shift

removelist="$1"
shift

section="$1"
shift

description="$1"
shift

depends="$1"
shift

builddeps=( $1 )
shift

conflicts="$1"
shift

replaces="$1"
shift

preinst="$1"
shift

postinst="$1"
shift

prerm="$1"
shift

postrm="$1"
shift

arch="$1"
shift

extraoptions=( $1 )
shift

if [[ -z "${pjtdir}" ]]
then
    pjtdir='.'
fi

if [[ "${buildtype,,}" == 'dkms' && name=*"-dkms" ]]
then
    name="${name%-*}"
fi

#### Check build dependencies ==================================================

if [[ "${buildtype,,}" == 'meson' ]]
then
    builddeps+=( 'meson' 'ninja-build' )
fi

missingpackages=()

for dep in "${builddeps[@]}"
do
    if [[ "$(dpkg-query -W --showformat='${Status}\n' $dep 2> /dev/null)" != 'install ok installed' ]]
    then
        missingpackages+=( "$dep" )
    fi
done

if [[ ${#missingpackages[@]} -gt 0 ]]
then
    echo "Missing dependency: ${missingpackages[*]}" >&2
    exit 1
fi

#### Create working dir ========================================================

if [[ -d "/dev/shm/deb-build" ]]
then
    rm -rf "/dev/shm/deb-build"
fi

rm -rf "package"

if [[ -d "/dev/shm" ]]
then
    mkdir -p "/dev/shm/deb-build/package"
    ln -s "/dev/shm/deb-build/package" "package"
else
    mkdir -p "package"
fi

#### Prepare and build project =================================================

#### Get architecture ----------------------------------------------------------

if [[ -z "$arch" ]]
then
    case "${buildtype,,}" in
    'install'|'copy'|'copyall'|'none')
        arch='all'
        ;;
        
    'make'|'cpp'|'c++'|'qt4'|'qt5'|'dkms'|'meson')
        arch="$(dpkg --print-architecture)"
        ;;
    esac
fi

#### Get build options ---------------------------------------------------------

unset prefix_name

unset cmd_clean
unset cmd_build
unset cmd_binary

declare -a cmd_clean
declare -a cmd_build
declare -a cmd_binary

cmd_clean=('@# Do nothing')
cmd_build=('@# Do nothing')

case "${buildtype,,}" in

'copy')

    cmd_binary=("rsync -a --exclude 'debian' --cvs-exclude \"${pjtdir}/\" \"$(realpath --relative-to="package/${pjtdir}" "package/debian")/${name}/\"")

;;

'copyall')

    cmd_binary=("rsync -av --exclude 'debian' --exclude '/.git' --exclude '/.svn' \"${pjtdir}/\" \"$(realpath --relative-to="package/${pjtdir}" "package/debian")/${name}/\"")

;;

'install')
    
    prefix_name='PREFIX'
    cmd_binary=("make -C \"${pjtdir}\" \$(SETPREFIX)  install")
    
;;

'make')

    prefix_name='PREFIX'
    cmd_clean=("make -C \"${pjtdir}\" clean")
    cmd_build=("make -C \"${pjtdir}\" -j\$(NPROC)")
    cmd_binary=("make -C \"${pjtdir}\" \$(SETPREFIX) install")

;;

'cpp'|'c++')

    prefix_name='PREFIX'
    cmd_clean=("make -C \"${pjtdir}\" clean")
    cmd_build=("make -C \"${pjtdir}\" -j\$(NPROC)")
    cmd_binary=("make -C \"${pjtdir}\" \$(SETPREFIX) install" 'dh_makeshlibs' 'dh_shlibdeps')

;;

'qt5')

    prefix_name='INSTALL_ROOT'
    cmd_clean=("qmake -qt=qt5 -o \"${pjtdir}/Makefile\" \"${pjtdir}\"" "make -C \"${pjtdir}\" clean")
    cmd_build=("qmake -qt=qt5 -o \"${pjtdir}/Makefile\" \"${pjtdir}\"" "make -C \"${pjtdir}\" -j\$(NPROC)")
    cmd_binary=("make -C \"${pjtdir}\" \$(SETPREFIX) install" 'dh_makeshlibs' 'dh_shlibdeps')
    
;;

'meson')

    cmd_clean=("rm -rf \"${pjtdir}/builddir\"")
    cmd_build=("cd \"${pjtdir}\" && meson setup builddir --buildtype release --strip" "meson configure \"${pjtdir}/builddir\" -Dprefix=/usr" "meson compile -C \"${pjtdir}/builddir\" -j \$(NPROC)")
    cmd_binary=("DESTDIR=\"\$(MESONPREFIX)\" meson install -C \"${pjtdir}/builddir\" --no-rebuild" 'dh_makeshlibs' 'dh_shlibdeps' 'dh_strip')
    
;;

'dkms')

;;

'none')

;;

*)

    echo "Unknown build type: ${type}" >&2
    false
    
;;

esac

cmd_binary+=('dh_gencontrol' 'dh_installdeb' )

if array_contains 'noconffiles' "${extraoptions[@]}"
then
    cmd_binary+=("rm -f debian/${name}/DEBIAN/conffiles")
fi

cmd_binary+=('dh_builddeb -- -Zxz')

#### Get sources ===============================================================

mkdir -p "package/${copyroot}"

if [[ -z "${vcs}" && -d "${path}" ]]
then
    cp -rf "${path}/." "package/${copyroot}/"
    
elif [[ "${vcs,,}" == 'git' ]] && git ls-remote "${path%%@*}" > /dev/null 2>/dev/null
then
    git clone --recurse-submodules -j$(nproc) "${path%%@*}" "package/${copyroot}"
    
    if [[ "${path}" == *@* ]]
    then
        pushd "package/${copyroot}" > /dev/null 2>/dev/null
        git checkout "${path#*@}"
        popd > /dev/null 2>/dev/null
    fi
    
elif [[ "${vcs,,}" == 'http.tar.gz' ]]
then
    if array_contains 'intellij' "${extraoptions[@]}"
    then
        curl "${path}" | tar xz --strip-components=1 -C "package/${copyroot}"
    else
        curl "${path}" | tar xz -C "package/${copyroot}"
    fi
fi

#### Get extra files -----------------------------------------------------------

if [[ -n "$extrafiles" && -d "$extrafiles" ]]
then
    cp -rf "$extrafiles/." 'package/'
fi

#### Remove files --------------------------------------------------------------

if [[ -n "$removelist" && -s "$removelist" ]]
then
    while read -r filename
    do
        rm -rf "package/${copyroot}/$filename"
    done <"$removelist"
fi

#### Get package information ===================================================

pushd "package/${copyroot}"

#### Get version and author from VCS -------------------------------------------

case "${vcs,,}" in
'git')
    [[ -z "${author}" ]] && author="$(git --no-pager show -s --format='%an <%ae>')"
    
    if [[ -z "${version}" ]]
    then
        if [[ -z "${versionrefpoint}" ]]
        then
            version="$(git rev-list HEAD --count)"
        else
            version="$(git rev-list "${versionrefpoint}"..HEAD --count)"
        fi
    fi
;;
'svn')
    [[ -z "${version}" ]] && version="$(svnversion .)"
;;

esac


case "${buildtype,,}" in
'dkms')
    versionseparator='.'
    ;;
*)
    versionseparator='-'
    ;;
esac

fullversion="$(join_by "$versionseparator" ${baseversion} ${version} ${builderversion})"

#### Generate Changelog from VCS -----------------------------------------------

#TODO: subj

changelog="${srcname} (${fullversion}) unstable; urgency=low
  * placeholder changelog to satisfy dpkg-gencontrol
 -- ${author}  $(date -R)
"

#### ---------------------------------------------------------------------------

popd

#### Build DKMS package ========================================================

if [[ "${buildtype,,}" == 'dkms' ]]
then
    sudo rsync -a --delete --delete-excluded --exclude '/.git' --exclude '/.svn' package/ "/usr/src/${name}-${fullversion}/"
    sudo dkms remove -m "${name}" -v "${fullversion}" --all || true
    sudo dkms add -m "${name}" -v "${fullversion}"
    #sudo dkms build -m "${name}" -v "${fullversion}"
    sudo dkms mkdeb --source-only -m "${name}" -v "${fullversion}"
    if [[ -f "/var/lib/dkms/${name}/${fullversion}/deb/${name}-dkms_${fullversion}_all.deb" ]]
    then
        cp "/var/lib/dkms/${name}/${fullversion}/deb/${name}-dkms_${fullversion}_all.deb" ./
    else
        cp "/var/lib/dkms/${name}/${fullversion}/deb/${name}-dkms_${fullversion}_${arch}.deb" ./
    fi
    
    sudo dkms remove -m "${name}" -v "${fullversion}" --all
    exit 0
fi

#### Build package =============================================================

mkdir -p package/debian

#### Generate control ----------------------------------------------------------

cat > package/debian/control <<_EOF
Source: ${srcname}
Maintainer: ${author}

Package: ${name}
Architecture: ${arch}
Depends: $(join_by ', ' "\${shlibs:Depends}" "\${misc:Depends}" "${depends}")
Conflicts: ${conflicts}
Replaces: ${replaces}
Section: ${section}
Priority: optional
Description: ${description}
_EOF

#### Generate changelog --------------------------------------------------------

echo "${changelog}" > package/debian/changelog

#### Generate compat -----------------------------------------------------------

echo '11' > package/debian/compat

#### Generate rules ------------------------------------------------------------

echo '#!/usr/bin/make -f' >  package/debian/rules
echo                      >> package/debian/rules

if [[ "${buildtype,,}" == 'meson' ]]
then
    echo "MESONPREFIX := \"$(realpath "package/debian")/${name}\"" >> package/debian/rules
fi

if [[ -n "${prefix_name}" ]]
then
    echo "SETPREFIX=\"${prefix_name}=\\\"$(realpath "package/debian")/${name}\\\"\"" >> package/debian/rules
    echo                                                                                                               >> package/debian/rules
fi

echo 'NPROC := $(if $(shell nproc),$(shell nproc),1)' >> package/debian/rules
echo                                                  >> package/debian/rules

cat >> package/debian/rules << _EOF
.PHONY: clean build binary

clean:
	$(join_by "\n    " "${cmd_clean[@]}")

build:
	$(join_by "\n    " "${cmd_build[@]}")

binary:
	$(join_by "\n    " "${cmd_binary[@]}")

_EOF

sed 's/^    /\t/g' -i package/debian/rules

#### Copy install/remove scripts -----------------------------------------------

for script in preinst postinst prerm postrm
do
    if [[ -n "${!script}" ]]
    then
        cp -f "${!script}" "package/debian/${name}.$script"
    fi
done

#### Generate package ----------------------------------------------------------

pushd package

if [[ "${arch}" == 'all' || "${arch}" == "$(dpkg --print-architecture)" ]]
then
    dpkg-buildpackage -b -us -uc
else
    dpkg-buildpackage -a${arch} -b -us -uc
fi

popd

#### Remove temp directory -----------------------------------------------------

if [[ -d "/dev/shm/deb-build" ]]
then
    cp -f "/dev/shm/deb-build/"*.deb ./
    rm -rf "/dev/shm/deb-build"
fi

rm -rf package *.buildinfo *.changes

#### ===========================================================================

