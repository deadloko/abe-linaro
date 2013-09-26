#!/bin/bash

# This script contains functions for building binary packages.

build_deb()
{
    trace "$*"

    warning "unimplemented"
}

build_rpm()
{
    trace "$*"

    warning "unimplemented"
}

# This removes files that don't go into a release, primarily stuff left
# over from development.
#
# $1 - the top level path to files to cleanup for a source release
sanitize()
{
    trace "$*"

    # the files left from random file editors we don't want.
    local edits="`find $1 -name \*~ -o -name \.\#\* -o -name \*.bak`"

    if test "`git st $1 | grep -c "nothing to commit, working directory clean"`" -eq 0; then
	error "uncommited files in $1! Commit files before releasing."
	return 1
    fi

    if test x"${edits}" != x; then
	rm -fr ${edits}
    fi

    return 0
}

# Build a binary tarball
# $1 - the version to use, usually something like 2013.07-2
binary_tarball()
{
    trace "$*"

    packages="sysroot toolchain"
    
    for i in ${packages}; do
	case $i in
	    toolchain)
		binary_toolchain ${release}
		;;
	    sysroot)
		binary_sysroot ${release}
		;;
	    *)
		echo "$i package building unimplemented"
		;;
	esac
    done
}

# Produce a binary toolchain tarball
# For daily builds produced by Jenkins, we use
# `date +%Y%m%d`-${BUILD_NUMBER}-${GIT_REVISION}
# e.g artifact_20130906-12-245f0869.tar.xz
binary_toolchain()
{
    trace "$*"

    local version="`${target}-gcc --version | head -1 | cut -d ' ' -f 3`"

    # See if specific component versions were specified at runtime
    if test x"${gcc_version}" = x; then
	local gcc_version="gcc-`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi

    if test `echo ${gcc_version} | grep -c "\.git/"`; then
	local branch="`basename ${gcc_version}`"
    else
	if test `echo ${gcc_version} | grep -c "\.git"`; then
	    local branch="master"
	fi
    fi

    if test "`echo $1 | grep -c '@'`" -gt 0; then
	local commit="@`echo $1 | cut -d '@' -f 2`"
    else
	local commit=""
    fi
    local builddir="`get_builddir ${gcc_version}`"
    local srcdir="`get_srcdir $1`"
    if test x"${release}" = x; then
	local release="`date +%Y%m%d`"
    fi
    if test -d ${srcdir}/.git; then
	local revision="git`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
    else
	local revision=${BUILD_NUMBER}
    fi
    if test `echo ${gcc_version} | grep -c "\.git/"`; then
	local version="`echo ${gcc_version} | cut -d '/' -f 1 | sed -e 's:\.git:-linaro:'`-${version}"
    fi
    local tag="`echo ${version}~${revision}-${target}-${host}-${release}${commit} | sed -e 's:-none-:-:' -e 's:-unknown-:-:'`"

    local destdir=/tmp/linaro/${tag}

    dryrun "mkdir -p ${destdir}/bin"
    dryrun "mkdir -p ${destdir}/share"
    dryrun "mkdir -p ${destdir}/lib/gcc"
    dryrun "mkdir -p ${destdir}/libexec/gcc"

    # Get the binaries
    dryrun "cp -r ${local_builds}/destdir/${host}/bin/${target}-* ${destdir}/bin/"
    dryrun "cp -r ${local_builds}/destdir/${host}/${target} ${destdir}/"
    dryrun "cp -r ${local_builds}/destdir/${host}/lib/gcc/${target} ${destdir}/lib/gcc/"
    dryrun "cp -r ${local_builds}/destdir/${host}/libexec/gcc/${target} ${destdir}/libexec/gcc/"

    if test -e /tmp/manifest.txt; then
	cp /tmp/manifest.txt ${destdir}
    fi

    # install in alternate directory so it's easier to build the tarball
    dryrun "make install SHELL=${bash_shell} ${make_flags} DESTDIR=${destdir} -w -C ${builddir}"

    # make the tarball from the tree we just created.
    dryrun "cd /tmp/linaro && tar Jcvf ${local_snapshots}/${tag}.tar.xz ${tag}"

    return 0
}

binary_sysroot()
{
    trace "$*"

    if test x"${clibrary}" = x"newlib"; then
	if test x"${newlb_version}" = x; then
	    local libc_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '=' -f 2 | cut -d '/' -f 1 | tr -d '\"'`"
	else
	    local libc_version="`echo ${newlib_version} | cut -d '/' -f 1`"
	    local srcdir="`get_srcdir $1`"
	fi
    else
	if test x"${eglibc_version}" = x; then
	    local libc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '/' -f 2 | tr -d '\"'`"
	    local srcdir="`get_srcdir $1`"
	    local libc_version="eglibc-linaro-`grep VERSION ${local_snapshots}/${libc_version}/libc/version.h | tr -d '\"' | cut -d ' ' -f 3`"
	else
	    local libc_version="`echo ${eglibc_version} | cut -d '/' -f 1`"
	    local srcdir="`get_srcdir $1`"
	    local libc_version="eglibc-linaro-`grep VERSION ${local_snapshots}/${libc_version}/libc/version.h | tr -d '\"' | cut -d ' ' -f 3`"
	fi
    fi

    if test "`echo $1 | grep -c '@'`" -gt 0; then
	local commit="@`echo $1 | cut -d '@' -f 2`"
    else
	local commit=""
    fi
    local version="`${target}-gcc --version | head -1 | cut -d ' ' -f 3`"
    if test x"${release}" = x; then
	release="`date +%Y%m%d`"
    fi
    if test -d ${srcdir}/.git; then
	local revision="`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
    else
	revision="${BUILD_NUMBER}"
    fi
    local tag="`echo sysroot-${libc_version}~${revision}-${target}-${release}-gcc_${version} | sed -e 's:\.git:-linaro:' -e 's:-none-:-:' -e 's:-unknown-:-:'`"

    dryrun "cp -fr ${cbuild_top}/sysroots/${target} /tmp/${tag}"

    dryrun "cd /tmp && tar Jcvf ${local_snapshots}/${tag}.tar.xz ${tag}"

    return 0
}

# Create a manifest file that lists all the versions of the other components
# used for this build.
manifest()
{
    if test x"$1" = x; then
	dest=/tmp
    else
	dest="`get_builddir $1`"
    fi

    if test x"${gcc_version}" = x; then
	gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${gmp_version}" = x; then
	gmp_version="`grep ^latest= ${topdir}/config/gmp.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${mpc_version}" = x; then
	mpc_version="`grep ^latest= ${topdir}/config/mpc.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${mpfr_version}" = x; then
	mpfr_version="`grep ^latest= ${topdir}/config/mpfr.conf | cut -d '\"' -f 2`"
    fi
    
    if test x"${binutils_version}" = x; then
	binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
    fi

    if test x"${eglibc_version}" = x; then
	eglibc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '\"' -f 2`"
    fi
        
    if test x"${newlib_version}" = x; then
	newlib_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
    fi
        
    if test x"${glibc_version}" = x; then
	glibc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '\"' -f 2`"
    fi        

    outfile=${dest}/manifest.txt
    cat <<EOF > ${outfile}
# Build machine data
build=${build}
kernel=${kernel}
hostname=${hostname}
distribution=${distribution}
host_gcc="${host_gcc_version}"

# Component versions
gmp_version=${gmp_version}
mpc_version=${mpc_version}
mpfr_version=${mpfr_version}
gcc_version=${gcc_version}
binutils_version=${binutils_version}
EOF
    
    if test x"${clibrary}" = x; then
	echo "eglibc_version=${eglibc_version}" >> ${outfile}
    else
	case ${clibrary} in
	    eglibc)
		echo "eglibc_version=${eglibc_version}" >> ${outfile}
		;;
	    glibc)
		echo "glibc_version=${glibc_version}" >> ${outfile}
		;;
	    newlib)
		echo "newlib_version=${newlib_version}" >> ${outfile}
		;;
	    *)
		echo "eglibc_version=${eglibc_version}" >> ${outfile}
		;;
	esac
    fi
}

# Build a source tarball
# $1 - the version to use, usually something like 2013.07-2
gcc_src_tarball()
{
    trace "$*"

    # See if specific component versions were specified at runtime
    if test x"${gcc_version}" = x; then
	local gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2` | tr -d '\"'"
    fi
    local version="`${target}-gcc --version | head -1 | cut -d ' ' -f 3`"
    local branch="`echo ${gcc_version} | cut -d '/' -f 2`"
    local srcdir="`get_srcdir ${gcc_version}`"
    local gcc_version="`echo ${gcc_version} | cut -d '/' -f 1 | sed -e 's:\.git:-linaro:'`-${version}"

    # clean up files that don't go into a release, often left over from development
    sanitize ${srcdir}

    if test "`echo $1 | grep -c '@'`" -gt 0; then
	local commit="@`echo $1 | cut -d '@' -f 2`"
    else
	local commit=""
    fi
    if test x"${release}" = x; then
	local release="`date +%Y%m%d`"
    fi
    if test -d ${srcdir}/.git; then
	local revision="~`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
	local exclude="--exclude .git"
    else
	local revision=""
	local exclude=""
    fi
    local tag="${gcc_version}${revision}-${release}${commit}"

    dryrun "ln -sfnT ${srcdir} /tmp/${tag}"
#    dryrun "cp -r ${srcdir} /tmp/${tag}"

    # Cleanup any temp files.
    #find ${srcdir} -name \*~ -o -name .\#\* -exec rm {} \;

    if test ! -f ${local_snapshots}/${tag}.tar.xz; then
	dryrun "cd /tmp && tar Jcvfh ${local_snapshots}/${tag}.tar.xz ${exclude} ${tag}/"
    fi

    # We don't need the symbolic link anymore.
    dryrun "rm -rf /tmp/${tag}"

    return 0
}

# Build a source tarball
# $1 - the version to use, usually something like 2013.07-2
binutils_src_tarball()
{
    trace "$*"

    # See if specific component versions were specified at runtime
    if test x"${gcc_version}" = x; then
	local gcc_version="gcc-`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi
    local dir="`normalize_path ${gcc_version}`"
    local srcdir="get_srcdir ${gcc_version}"
    local builddir="`get_bulddir ${gcc_version}`"

    # clean up files that don't go into a release, often left over from development
    sanitize ${srcdir}

    # from /linaro/snapshots/binutils.git/src-release: do-proto-toplev target
    # Take out texinfo from a few places.
    dirs="`find ${srcdir} -name Makefile.in`"
    for d in ${dirs}; do
	sed -i -e '/^all\.normal: /s/\all-texinfo //' -e '/^install-texinfo /d' $d
    done

    # Make links, and run "make diststuff" or "make info" when needed
    dirs="`find ${builddir} -name Makefile`"
    for d in ${dirs}; do
	if test -f $d; then
	    if test `grep -c '^diststuff:' $d` -gt 0; then
		$(MAKE) -C $d MAKEINFOFLAGS="$(MAKEINFOFLAGS)" diststuff
	    fi
	    if test `grep -c '^info:' $d` -gt 0; then
		$(MAKE) -C $d MAKEINFOFLAGS="$(MAKEINFOFLAGS) " info
	    fi
	fi
    done
    # Create .gmo files from .po files.
    for f in `find . -name '*.po' -type f -print`; do
        msgfmt -o `echo $f | sed -e 's/\.po$/.gmo/'` $f
    done
 
    local date="`date +%Y%m%d`"
    if test "`echo $1 | grep -c '@'`" -gt 0; then
	local commit="`echo $1 | cut -d '@' -f 2`"
    else
	local commit=""
    fi
    if test -d ${srcdir}/.git; then
	local gcc_version="${dir}-${date}"
	local revision="-`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"
	local exclude="${exclude} .git"
    else
	local gcc_version="`echo ${gcc_version} | sed -e "s:-2.*:-${date}:"`"
	local revision=""
	local exclude=""
    fi
    local tag="${gcc_version}${revision}${commit}"

    dryrun "ln -s ${srcdir} /tmp/${tag}"

# from /linaro/snapshots/binutils-2.23.2/src-release
#
# NOTE: No double quotes in the below.  It is used within shell script
# as VER="$(VER)"

    if grep 'AM_INIT_AUTOMAKE.*BFD_VERSION' $(TOOL)/configure.in >/dev/null 2>&1; then
	sed < bfd/configure.in -n 's/AM_INIT_AUTOMAKE[^,]*, *\([^)]*\))/\1/p';
    elif grep AM_INIT_AUTOMAKE $(TOOL)/configure.in >/dev/null 2>&1; then
	sed < $(TOOL)/configure.in -n 's/AM_INIT_AUTOMAKE[^,]*, *\([^)]*\))/\1/p';
    elif test -f $(TOOL)/version.in; then
	head -1 $(TOOL)/version.in;
    elif grep VERSION $(TOOL)/Makefile.in > /dev/null 2>&1; then
	sed < $(TOOL)/Makefile.in -n 's/^VERSION *= *//p';
    else
	echo VERSION;
    fi

    # Cleanup any temp files.
    #find ${srcdir} -name \*~ -o -name .\#\* -exec rm {} \;

    dryrun "cd /tmp && tar ${exclude} Jcvfh ${local_snapshots}/${tag}.tar.xz ${tag}/"

    # We don't need the symbolic link anymore.
    dryrun "rm -f /tmp/${tag}"

    return 0
}

