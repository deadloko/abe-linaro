#!/bin/bash

# common.sh loads all the files of library functions.
if test x"`echo \`dirname "$0"\` | sed 's:^\./::'`" != x"testsuite"; then
    echo "WARNING: Should be run from top abe dir" > /dev/stderr
    topdir="`readlink -e \`dirname $0\`/..`"
else
    topdir=$PWD
fi

# configure generates host.conf from host.conf.in.
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
    . "${topdir}/lib/common.sh" || exit 1
else
    build="`sh ${topdir}/config.guess`"
    . "${topdir}/lib/common.sh" || exit 1
    warning "no host.conf file!  Synthesizing a framework for testing."

    remote_snapshots=http://abe.validation.linaro.org/snapshots
    wget_bin=/usr/bin/wget
    sources_conf=${topdir}/testsuite/test_sources.conf
fi
echo "Testsuite using ${sources_conf}"

# Use wget -q in the testsuite
wget_quiet=yes

# We always override $local_snapshots so that we don't damage or move the
# local_snapshots directory of an existing build.
local_abe_tmp="`mktemp -d /tmp/abe.$$.XXX`"
local_snapshots="${local_abe_tmp}/snapshots"

# If this isn't being run in an existing build dir, create one in our
# temp directory.
if test ! -d "${local_builds}"; then
    local_builds="${local_abe_tmp}/builds"
    out="`mkdir -p ${local_builds}`"
    if test "$?" -gt 1; then
	error "Couldn't create local_builds dir ${local_builds}"
	exit 1
    fi
fi

# Let's make sure that the snapshots portion of the directory is created before
# we use it just to be safe.
out="`mkdir -p ${local_snapshots}`"
if test "$?" -gt 1; then
    error "Couldn't create local_snapshots dir ${local_snapshots}"
    exit 1
fi

# Let's make sure that the build portion of the directory is created before
# we use it just to be safe.
out="`mkdir -p ${local_snapshots}`"


# Since we're testing, we don't load the host.conf file, instead
# we create false values that stay consistent.
abe_top=/build/abe/test
hostname=test.foobar.org
target=x86_64-linux-gnu

if test x"$1" = x"-v"; then
    debug=yes
fi

fixme()
{
    if test x"${debug}" = x"yes"; then
	echo "($BASH_LINENO): $*" 1>&2
    fi
}

passes=0
pass()
{
    echo "PASS: $1"
    passes="`expr ${passes} + 1`"
}

xpasses=0
xpass()
{
    echo "XPASS: $1"
    xpasses="`expr ${xpasses} + 1`"
}

untested=0
untested()
{
    echo "UNTESTED: $1"
    untested="`expr ${untested} + 1`"
}

failures=0
fail()
{
    echo "FAIL: $1"
    failures="`expr ${failures} + 1`"
}

xfailures=0
xfail()
{
    echo "XFAIL: $1"
    xfailures="`expr ${xfailures} + 1`"
}

totals()
{
    echo ""
    echo "Total test results:"
    echo "	Passes: ${passes}"
    echo "	Failures: ${failures}"
    if test ${xfailures} -gt 0; then
	echo "	Expected Failures: ${xfailures}"
    fi
    if test ${untested} -gt 0; then
	echo "	Untested: ${untested}"
    fi
}

#
# common.sh tests
#
# Pretty much everything uses the git parser so test it first.
. "${topdir}/testsuite/git-parser-tests.sh"
. "${topdir}/testsuite/stamp-tests.sh"
. "${topdir}/testsuite/normalize-tests.sh"
. "${topdir}/testsuite/builddir-tests.sh"
. "${topdir}/testsuite/report-tests.sh"

# ----------------------------------------------------------------------------------

echo "============= get_toolname() tests ================"

testing="get_toolname: uncompressed tarball"
in="http://abe.validation.linaro.org/snapshots/gdb-7.6~20121001+git3e2e76a.tar"
out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: compressed tarball"
in="http://abe.validation.linaro.org/snapshots/gcc-linaro-4.8-2013.06-1.tar.xz"
out="`get_toolname ${in}`"
if test ${out} = "gcc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: svn branch"
in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`get_toolname ${in}`"
if test ${out} = "gcc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: bzr <repo> -linaro/<branch>"
in="lp:gdb-linaro/7.5"
out="`get_toolname ${in}`"
if test ${out} = "gdb"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>[no .git suffix]"
in="git://git.linaro.org/toolchain/binutils"
out="`get_toolname ${in}`"
if test ${out} = "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>[no .git suffix]/<branch> isn't supported."
in="git://git.linaro.org/toolchain/binutils/branch"
out="`get_toolname ${in}`"
if test ${out} != "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>[no .git suffix]/<branch>@<revision> isn't supported."
in="git://git.linaro.org/toolchain/binutils/branch@12345"
out="`get_toolname ${in}`"
if test ${out} != "binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>[no .git suffix]@<revision>."
# This works, but please don't do this.
in="git://git.linaro.org/toolchain/binutils@12345"
out="`get_toolname ${in}`"
match="binutils"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} but expected ${match}"
fi

# ----------------------------------------------------------------------------------
# Test git:// git combinations
testing="get_toolname: git://<repo>.git"
in="git://git.linaro.org/toolchain/binutils.git"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git/<branch>"
in="git://git.linaro.org/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git/<branch>@<revision>"
in="git://git.linaro.org/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: git://<repo>.git@<revision>"
in="git://git.linaro.org/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi
# ----------------------------------------------------------------------------------
# Test http:// git combinations
testing="get_toolname: http://<repo>.git"
in="http://staging.git.linaro.org/git/toolchain/binutils.git"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git/<branch>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git/<branch>@<revision>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<repo>.git@<revision>"
in="http://staging.git.linaro.org/git/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
# Test http://<user>@ git combinations
testing="get_toolname: http://<user>@<repo>.git"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git/<branch>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git/<branch>@<revision>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git/2.4-branch@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: http://<user>@<repo>.git@<revision>"
in="http://git@staging.git.linaro.org/git/toolchain/binutils.git@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"binutils"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

# ----------------------------------------------------------------------------------
testing="get_toolname: sources.conf identifier <repo>.git"
in="eglibc.git"
out="`get_toolname ${in}`"
if test x"${out}" = x"eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git/<branch>"
in="eglibc.git/linaro_eglibc-2_18"
out="`get_toolname ${in}`"
if test x"${out}" = x"eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git/<branch>@<revision>"
in="eglibc.git/linaro_eglibc-2_18@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: sources.conf identifier <repo>.git@<revision>"
in="eglibc.git@12345"
out="`get_toolname ${in}`"
if test x"${out}" = x"eglibc"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out}"
fi

testing="get_toolname: combined binutils-gdb repository with gdb branch"
in="binutils-gdb.git/gdb_7_6-branch"
out="`get_toolname ${in}`"
match="gdb"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} expected ${match}"
fi

testing="get_toolname: combined binutils-gdb repository with binutils branch"
in="binutils-gdb.git/binutils-2_24"
out="`get_toolname ${in}`"
match="binutils"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} but expected ${match}"
fi

# The special casing for binutils-gdb.git was failing in this one.
testing="get_toolname: combined binutils-gdb repository with linaro binutils branch"
in="binutils-gdb.git/linaro_binutils-2_24_branch"
out="`get_toolname ${in}`"
match="binutils"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} but expected ${match}"
fi



testing="get_toolname: svn archive with /trunk trailing designator"
in="http://llvm.org/svn/llvm-project/cfe/trunk"
out="`get_toolname ${in}`"
match="cfe"
if test x"${out}" = x"${match}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "${in} returned ${out} but expected ${match}"
fi

# ----------------------------------------------------------------------------------
echo "============= fetch() tests ================"
out="`fetch md5sums 2>/dev/null`"
if test $? -eq 0; then
    pass "fetch md5sums"
else
    fail "fetch md5sums"
fi

# Fetching again to test the .bak functionality.
out="`fetch md5sums 2>/dev/null`"
if test $? -eq 0; then
    pass "fetch md5sums"
else
    fail "fetch md5sums"
fi

if test ! -e "${local_snapshots}/md5sums"; then
    fail "Did not find ${local_snapshots}/md5sums"
    echo "md5sums needed for snapshots, get_URL, and get_sources tests.  Check your network connectivity." 1>&2
    exit 1;
else
    pass "Found ${local_snapshots}/md5sums"
fi

if test ! -e "${local_snapshots}/md5sums.bak"; then
    fail "Did not find ${local_snapshots}/md5sums.bak"
else
    pass "Found ${local_snapshots}/md5sums.bak"
fi
# ----------------------------------------------------------------------------------
echo "============= find_snapshot() tests ================"

testing="find_snapshot: not unique tarball name"
out="`find_snapshot gcc 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "find_snapshot returned ${out}"
fi

testing="find_snapshot: unique tarball name"
out="`find_snapshot gcc-linaro-4.8-2013.08`"
if test $? -eq 0; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "find_snapshot returned ${out}"
fi

testing="find_snapshot: unknown tarball name"
out="`find_snapshot gcc-linaro-4.8-2013.06XXX 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "find_snapshot returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() tests ================"

# This will dump an error to stderr, so squelch it.
testing="get_URL: non unique identifier shouldn't match in sources.conf."
out="`get_URL gcc 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: unmatching snapshot not found in sources.conf file"
out="`get_URL gcc-linaro-4.8-2013.06-1 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: git URL where sources.conf has a tab"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL gcc_tab.git`"
    if test x"`echo ${out}`" = x"http://staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: nomatch.git@<revision> shouldn't have a corresponding sources.conf url."
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL nomatch.git@12345 2>/dev/null`"
    if test x"${out}" = x""; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

echo "============= get_URL() tests with erroneous service:// inputs ================"

testing="get_URL: Input contains an lp: service."
out="`get_URL lp:cortex-strings 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Input contains a git:// service."
out="`get_URL git://git.linaro.org/toolchain/eglibc.git 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Input contains an http:// service."
out="`get_URL http://staging.git.linaro.org/git/toolchain/eglibc.git 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Input contains an svn:// service."
out="`get_URL svn://gcc.gnu.org/svn/gcc/branches/gcc-4_6-branch 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() [git|http]:// tests ================"
testing="get_URL: sources.conf <repo>.git identifier should match git://<url>/<repo>.git"
out="`get_URL glibc.git`"
if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://git.linaro.org/git/toolchain/glibc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
out="`get_URL glibc.git/branch`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~branch"; then
    pass "${testing} http://<url>/<repo>.git"
else
    fail "${testing} http://<url>/<repo>.git"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<multi/part/branch> identifier should match"
out="`get_URL glibc.git/multi/part/branch`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~multi/part/branch"; then
    pass "${testing} http://<url>/<repo>.git/multi/part/branch"
else
    fail "${testing} http://<url>/<repo>.git/multi/part/branch"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git~<branch> identifier should match"
out="`get_URL glibc.git~branch`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~branch"; then
    pass "${testing} http://<url>/<repo>.git~branch"
else
    fail "${testing} http://<url>/<repo>.git~branch"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git~<multi/part/branch> identifier should match"
out="`get_URL glibc.git~multi/part/branch`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~multi/part/branch"; then
    pass "${testing} http://<url>/<repo>.git~multi/part/branch"
else
    fail "${testing} http://<url>/<repo>.git~multi/part/branch"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
out="`get_URL glibc.git/branch@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~branch@12345"; then
    pass "${testing} http://<url>/<repo>.git/<branch>@<revision>"
else
    fail "${testing} http://<url>/<repo>.git/<branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git/<mulit/part/branch>@<revision> identifier should match"
out="`get_URL glibc.git/multi/part/branch@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~multi/part/branch@12345"; then
    pass "${testing} http://<url>/<repo>.git/<multi/part/branch>@<revision>"
else
    fail "${testing} http://<url>/<repo>.git/<multi/part/branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git~<branch>@<revision> identifier should match"
out="`get_URL glibc.git~branch@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~branch@12345"; then
    pass "${testing} http://<url>/<repo>.git~<branch>@<revision>"
else
    fail "${testing} http://<url>/<repo>.git~<branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git~<mulit/part/branch>@<revision> identifier should match"
out="`get_URL glibc.git~multi/part/branch@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git~multi/part/branch@12345"; then
    pass "${testing} http://<url>/<repo>.git~<multi/part/branch>@<revision>"
else
    fail "${testing} http://<url>/<repo>.git~<multi/part/branch>@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
out="`get_URL glibc.git@12345`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/glibc.git@12345"; then
    pass "${testing} http://<url>/<repo>.git@<revision>"
else
    fail "${testing} http://<url>/<repo>.git@<revision>"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: sources.conf <repo>.git identifier should match http://<url>/<repo>.git"
out="`get_URL gcc.git`"
if test x"`echo ${out}`" = x"http://git.linaro.org/git/toolchain/gcc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Don't match partial match of <repo>[spaces] to sources.conf identifier."
out="`get_URL "eglibc" 2>/dev/null`"
if test x"`echo ${out}`" = x; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

testing="get_URL: Don't match partial match of <repo>[\t] to sources.conf identifier."
out="`get_URL "gcc_tab" 2>/dev/null`"
if test x"`echo ${out}`" = x; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_URL returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() http://git@ tests ================"

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git identifier should match http://git@<url>/<repo>.git"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL git_gcc.git`"
    if test x"`echo ${out}`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL git_gcc.git/branch`"
    if test x"`echo ${out}`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git~branch"; then
	pass "${testing} http://git@<url>/<repo>.git~<branch>"
    else
	fail "${testing} http://git@<url>/<repo>.git~<branch>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://git@<url>/<repo>.git"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL git_gcc.git/branch@12345`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git~branch@12345"; then
	pass "${testing} http://git@<url>/<repo>.git~<branch>@<revision>"
    else
	fail "${testing} http://git@<url>/<repo>.git~<branch>@<revision>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://git@<url>/<repo>.git"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL git_gcc.git@12345`"
    if test x"`echo ${out}`" = x"http://git@staging.git.linaro.org/git/toolchain/gcc.git@12345"; then
	pass "${testing} http://git@<url>/<repo>.git@<revision>"
    else
	fail "${testing} http://git@<url>/<repo>.git@<revision>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://git@<url>/<repo>.git"
fi

# ----------------------------------------------------------------------------------
echo "============= get_URL() http://user.name@ tests ================"
# We do these these tests to make sure that 'http://git@'
# isn't hardcoded in the scripts.

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git identifier should match http://user.name@<url>/<repo>.git"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL user_gcc.git`"
    if test x"`echo ${out}`" = x"http://user.name@staging.git.linaro.org/git/toolchain/gcc.git"; then
	pass "${testing} http://<user.name>@<url>/<repo>.git"
    else
	fail "${testing} http://<user.name>@<url>/<repo>.git"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL user_gcc.git/branch`"
    if test x"`echo ${out}`" = x"http://user.name@staging.git.linaro.org/git/toolchain/gcc.git~branch"; then
	pass "${testing} http://user.name@<url>/<repo>.git~<branch>"
    else
	fail "${testing} http://user.name@<url>/<repo>.git~<branch>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://user.name@<url>/<repo>.git"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git/<branch>@<revision> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL user_gcc.git/branch@12345`"
    if test x"`echo ${out} | cut -d ' ' -f 1`" = x"http://user.name@staging.git.linaro.org/git/toolchain/gcc.git~branch@12345"; then
	pass "${testing} http://user.name@<url>/<repo>.git~<branch>@<revision>"
    else
	fail "${testing} http://user.name@<url>/<repo>.git~<branch>@<revision>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://username@<url>/<repo>.git"
fi

# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf <repo>.git@<revision> identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL user_gcc.git@12345`"
    if test x"`echo ${out}`" = x"http://user.name@staging.git.linaro.org/git/toolchain/gcc.git@12345"; then
	pass "${testing} http://user.name@<url>/<repo>.git@<revision>"
    else
	fail "${testing} http://user.name@<url>/<repo>.git@<revision>"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing} http://username@<url>/<repo>.git"
fi

echo "============= get_URL() svn and lp tests ================"
# The regular sources.conf won't have this entry.
testing="get_URL: sources.conf svn identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL gcc-svn-4.8`"
    if test x"`echo ${out}`" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_8-branch"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_URL: sources.conf launchpad identifier should match"
if test ! -e "${PWD}/host.conf"; then
    out="`get_URL cortex-strings`"
    if test x"`echo ${out}`" = x"lp:cortex-strings"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_URL returned ${out}"
    fi
else
    untested "${testing}"
fi

# ----------------------------------------------------------------------------------
#
# Test package building

# dryrun=yes
# #gcc_version=linaro-4.8-2013.09
# gcc_version=git://git.linaro.org/toolchain/gcc.git/fsf-gcc-4_8-branch

# out="`binary_toolchain 2>&1 | tee xx |grep "DRYRUN:.*Jcvf"`"

# date="`date +%Y%m%d`"
# tarname="`echo $out | cut -d ' ' -f 9`"
# destdir="`echo $out | cut -d ' ' -f 10`"
# match="${local_snapshots}/gcc.git-${target}-${host}-${date}"

# if test "`echo ${tarname} | grep -c ${match}`" -eq 1; then
#     pass "binary_toolchain: git repository"
# else
#     fail "binary_toolchain: git repository"
#     fixme "get_URL returned ${out}"
# fi

# #binutils_version=linaro-4.8-2013.09
# binutils_version=git://git.linaro.org/toolchain/binutils.git
# out="`binary_sysroot 2>&1 | tee xx |grep "DRYRUN:.*Jcvf"`"
# tarname="`echo $out | cut -d ' ' -f 9`"
# destdir="`echo $out | cut -d ' ' -f 10`"
# match="${local_snapshots}/sysroot-eglibc-linaro-2.18-2013.09-${target}-${date}"
# echo "${tarname}"
# echo "${match}"
# if test "`echo ${tarname} | grep -c ${match}`" -eq 1; then
#     pass "binary_toolchain: git repository"
# else
#     fail "binary_toolchain: git repository"
#     fixme "get_URL returned ${out}"
# fi
# dryrun=no

echo "============= get_source() tests ================"
# TODO Test ${sources_conf} for ${in} for relevant tests.
#      Mark tests as untested if the expected match isn't in sources_conf.
#      This might be due to running testsuite in a builddir rather than a
#      source dir.

# get_sources might, at times peak at latest for a hint if it can't find
# things.  Keep it unset unless you want to test a specific code leg.
saved_latest=${latest}
latest=''

# Test get_source with a variety of inputs
testing="get_source: unknown repository"
in="somethingbogus"
out="`get_source ${in} 2>&1`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned \"${out}\""
fi

testing="get_source: empty url"
in=''
out="`get_source ${in} 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned \"${out}\""
fi

testing="get_source: git repository"
in="eglibc.git"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/eglibc.git"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git repository with / branch"
in="eglibc.git/linaro_eglibc-2_17"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/eglibc.git~linaro_eglibc-2_17"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git repository with / branch and commit"
in="newlib.git/binutils-2_23-branch@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/newlib.git~binutils-2_23-branch@e9a210b"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: git repository with ~ branch and commit"
in="newlib.git~binutils-2_23-branch@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/newlib.git~binutils-2_23-branch@e9a210b"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: <repo>.git@commit"
in="newlib.git@e9a210b"
out="`get_source ${in}`"
if test x"${out}" = x"http://git.linaro.org/git/toolchain/newlib.git@e9a210b"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: tar.bz2 archive"
in="gcc-linaro-4.8-2013.09.tar.xz"
out="`get_source ${in}`"
if test x"${out}" = x"gcc-linaro-4.8-2013.09.tar.xz"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned \"${out}\""
fi

testing="get_source: Too many snapshot matches."
in="gcc-linaro"
out="`get_source ${in} 2>/dev/null`"
if test $? -eq 1; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: Non-git direct url"
in="svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"
out="`get_source ${in}`"
if test x"${out}" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_7-branch"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

for transport in ssh git http; do
  testing="get_source: git direct url not ending in .git (${transport})"
  in="${transport}://git.linaro.org/toolchain/eglibc"
  out="`get_source ${in}`"
  if test x"${out}" = x"${transport}://git.linaro.org/toolchain/eglibc"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "get_source returned ${out}"
  fi

  testing="get_source: git direct url not ending in .git with revision returns bogus url. (${transport})"
  in="${transport}://git.linaro.org/git/toolchain/eglibc/branch@1234567"
  if test x"${debug}" = x"yes"; then
      out="`get_source ${in}`"
  else
      out="`get_source ${in} 2>/dev/null`"
  fi
  if test x"${out}" = x"${transport}://git.linaro.org/git/toolchain/eglibc/branch@1234567"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "get_source returned ${out}"
  fi
done

# These aren't valid if testing from a build directory.
testing="get_source: full url with <repo>.git with no matching source.conf entry should fail."
if test ! -e "${PWD}/host.conf"; then
    in="http://git.linaro.org/git/toolchain/foo.git"
    if test x"${debug}" = x"yes"; then
        out="`get_source ${in}`"
    else
        out="`get_source ${in} 2>/dev/null`"
    fi
    if test x"${out}" = x"http://git.linaro.org/git/toolchain/foo.git"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

# These aren't valid if testing from a build directory.
testing="get_source: <repo>.git identifier with no matching source.conf entry should fail."
if test ! -e "${PWD}/host.conf"; then
    in="nomatch.git"
    if test x"${debug}" = x"yes"; then
        out="`get_source ${in}`"
    else
        out="`get_source ${in} 2>/dev/null`"
    fi
    if test x"${out}" = x""; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

# These aren't valid if testing from a build directory.
testing="get_source: <repo>.git@<revision> identifier with no matching source.conf entry should fail."
if test ! -e "${PWD}/host.conf"; then
    in="nomatch.git@12345"

    if test x"${debug}" = x"yes"; then
	out="`get_source ${in}`"
    else
	out="`get_source ${in} 2>/dev/null`"
    fi

    if test x"${out}" = x""; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_source: tag matching an svn repo in ${sources_conf}"
in="gcc-4.8-"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"svn://gcc.gnu.org/svn/gcc/branches/gcc-4_8-branch"; then
    xpass "${testing}"
else
    # This currently is expected to fail because passing in gcc-4.8 is assumed
    # to be a tarball in md5sums, and so it;s never looked up in sources.conf.
    # Not sure if this is a bug or an edge case, as specifying  more unique
    # URL for svn works correctly.
    xfail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: <repo>.git matches non .git suffixed url."
in="foo.git"
if test ! -e "${PWD}/host.conf"; then
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x"git://testingrepository/foo"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_source: <repo>.git/<branch> matches non .git suffixed url."
in="foo.git/bar"
if test ! -e "${PWD}/host.conf"; then
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x"git://testingrepository/foo~bar"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_source: <repo>.git/<branch>@<revision> matches non .git suffixed url."
in="foo.git/bar@12345"
if test ! -e "${PWD}/host.conf"; then
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x"git://testingrepository/foo~bar@12345"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

in="foo.git@12345"
testing="get_source: ${sources_conf}:${in} matching no .git in <repo>@<revision>."
if test ! -e "${PWD}/host.conf"; then
    out="`get_source ${in} 2>/dev/null`"
    if test x"${out}" = x"git://testingrepository/foo@12345"; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "get_source returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="get_source: partial match in snapshots, latest not set."
latest=''
in="gcc-linaro-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x""; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

testing="get_source: too many matches in snapshots, latest set."
latest="gcc-linaro-4.8-2013.09.tar.xz"
in="gcc-linaro-4.8"
out="`get_source ${in} 2>/dev/null`"
if test x"${out}" = x"gcc-linaro-4.8-2013.09.tar.xz"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "get_source returned ${out}"
fi

latest=${saved_latest}

for transport in ssh git http; do
  testing="get_source: git direct url with a ~ branch designation. (${transport})"
  in="${transport}://git.linaro.org/toolchain/eglibc.git~branch@1234567"
  if test x"${debug}" = x"yes"; then
      out="`get_source ${in}`"
  else
      out="`get_source ${in} 2>/dev/null`"
  fi
  if test x"${out}" = x"${transport}://git.linaro.org/toolchain/eglibc.git~branch@1234567"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "get_source returned ${out}"
  fi

  testing="get_source: git direct url with a ~ branch designation. (${transport})"
  in="$transport://git.savannah.gnu.org/dejagnu.git~linaro"
  if test x"${debug}" = x"yes"; then
      out="`get_source ${in}`"
  else
      out="`get_source ${in} 2>/dev/null`"
  fi
  if test x"${out}" = x"${transport}://git.savannah.gnu.org/dejagnu.git~linaro"; then
      pass "${testing}"
  else
      fail "${testing}"
      fixme "get_source returned ${out}"
  fi
done




# ----------------------------------------------------------------------------------

echo "========= create_release_tag() tests ============"

testing="create_release_tag: repository with branch and revision"
date="`date +%Y%m%d`"
in="gcc.git/gcc-4.8-branch@12345abcde"
out="`create_release_tag ${in} | grep -v TRACE`"
toolname="`echo ${out} | cut -d ' ' -f 1`"
branch="`echo ${out} | cut -d ' ' -f 2`"
revision="`echo ${out} | cut -d ' ' -f 3`"
if test x"${out}" = x"gcc.git~gcc-4.8-branch@12345abcde-${date}"; then
    pass "${testing}"
else
    fail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

branch=
revision=
testing="create_release_tag: repository branch empty"
if test -d ${srcdir}; then
    in="gcc.git"
    out="`create_release_tag ${in} | grep -v TRACE`"
    if test "`echo ${out} | grep -c "gcc.git-${date}"`" -gt 0; then
	pass "${testing}"
    else
	fail "${testing}"
	fixme "create_release_tag returned ${out}"
    fi
else
    untested "${testing}"
fi

testing="create_release_tag: tarball"
in="gcc-linaro-4.8-2013.09.tar.xz"
out="`create_release_tag ${in} | grep -v TRACE`"
if test x"${out}" = x"gcc-linaro-4.8-${date}"; then
    xpass "${testing}"
else
    # This fails because the tarball name fails to extract the version. This
    # behavious isn't used by Abe, it was an early feature to have some
    # compatability with abev1, which used tarballs. Abe produces the
    # tarballs, it doesn't need to import them anymore.
    xfail "${testing}"
    fixme "create_release_tag returned ${out}"
fi

# ----------------------------------------------------------------------------------
echo "============= checkout () tests ================"
echo "  Checking out sources into ${local_snapshots}"
echo "  Please be patient while sources are checked out...."
echo "================================================"

# These can be painfully slow so test small repos.

test_checkout ()
{
    local should="$1"
    local testing="$2"
    local package="$3"
    local branch="$4"
    local revision="$5"

    #in="${package}${branch:+/${branch}}${revision:+@${revision}}"
    in="${package}${branch:+~${branch}}${revision:+@${revision}}"

    local gitinfo=
    gitinfo="`get_URL ${in}`"

    local tag=
    tag="`get_git_url ${gitinfo}`"
    tag="${tag}${branch:+~${branch}}${revision:+@${revision}}"

    # We also support / designated branches, but want to move to ~ mostly.
    #tag="${tag}${branch:+~${branch}}${revision:+@${revision}}"

    if test x"${debug}" = x"yes"; then
	out="`(cd ${local_snapshots} && checkout ${tag})`"
    else
	out="`(cd ${local_snapshots} && checkout ${tag} 2>/dev/null)`"
    fi

    local srcdir=
    srcdir="`get_srcdir "${tag}"`"

    local branch_test=
    if test ! -d ${srcdir}; then
	branch_test=0
    elif test x"${branch}" = x -a x"${revision}" = x; then
	branch_test=`(cd ${srcdir} && git branch | grep -c "^\* master$")`
    else
	branch_test=`(cd ${srcdir} && git branch | grep -c "^\* ${branch:+${branch}${revision:+_}}${revision:+${revision}}$")`
    fi

    if test x"${branch_test}" = x1 -a x"${should}" = xpass; then
	pass "${testing}"
	return 0
    elif test x"${branch_test}" = x1 -a x"${should}" = xfail; then
	fail "${testing}"
	return 1
    elif test x"${branch_test}" = x0 -a x"${should}" = xfail; then
	pass "${testing}"
	return 0
    else
	fail "${testing}"
	return 1
    fi
}

testing="checkout: http://git@<url>/<repo>.git"
if test ! -e "${PWD}/host.conf"; then
   package="abe.git"
   branch=''
   revision=''
   should="pass"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git/<branch>"
if test ! -e "${PWD}/host.conf"; then
   package="abe.git"
   branch="gerrit"
   revision=''
   should="pass"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git@<revision>"
if test ! -e "${PWD}/host.conf"; then
   package="abe.git"
   branch=''
   revision="9bcced554dfc"
   should="pass"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git/unusedbranchnanme@<revision>"
if test ! -e "${PWD}/host.conf"; then
   package="abe.git"
   branch="unusedbranchname"
   revision="9bcced554dfc"
   should="pass"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git/<nonexistentbranch> should fail."
if test ! -e "${PWD}/host.conf"; then
   package="abe.git"
   branch="nonexistentbranch"
   revision=''
   should="fail"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

testing="checkout: http://git@<url>/<repo>.git@<nonexistentrevision> should fail."
if test ! -e "${PWD}/host.conf"; then
   package="abe.git"
   branch=''
   revision="123456bogusbranch"
   should="fail"
   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
else
    untested "${testing}"
fi

echo "============= misc tests ================"
testing="pipefail"
out="`false | tee /dev/null`"
if test $? -ne 0; then
    pass "${testing}"
else
    fail "${testing}"
fi

#Do not pollute env
testing="source_config"
depends="`depends= && source_config isl && echo ${depends}`"
static_link="`static_link= && source_config isl && echo ${static_link}`"
default_configure_flags="`default_configure_flags= && source_config isl && echo ${default_configure_flags}`"
if test x"${depends}" != xgmp; then
  fail "${testing}"
elif test x"${static_link}" != xyes; then
  fail "${testing}"
elif test x"${default_configure_flags}" != x"--with-gmp-prefix=${PWD}/${hostname}/${build}/depends"; then
  fail "${testing}"
else
  pass "${testing}"
fi
depends=
default_configure_flags=
static_link=

testing="read_config one arg"
if test x"`read_config isl static_link`" = xyes; then
  pass "${testing}"
else
  fail "${testing}"
fi

testing="read_config multiarg"
if test x"`read_config glib default_configure_flags`" = x"--disable-modular-tests --disable-dependency-tracking --cache-file=/tmp/glib.cache"; then
  pass "${testing}"
else
  fail "${testing}"
fi

testing="read_config set then unset"
out="`default_makeflags=\`read_config binutils default_makeflags\` && default_makeflags=\`read_config newlib default_makeflags\` && echo ${default_makeflags}`"
if test $? -gt 0; then
  fail "${testing}"
elif test x"${out}" != x; then
  fail "${testing}"
else
  pass "${testing}"
fi

dryrun="yes"
tool="binutils" #this is a nice tool to use as it checks the substitution in make install, too
cmp_makeflags="`read_config ${tool} default_makeflags`"
testing="postfix make args (make_all)"
if test x"${cmp_makeflags}" = x; then
  untested "${testing}" #implies that the config for this tool no longer contains default_makeflags
else
  out="`. ${topdir}/config/${tool}.conf && make_all ${tool}.git 2>&1`"
  if test x"${debug}" = x"yes"; then
    echo "${out}"
  fi
  echo "${out}" | grep -- "${cmp_makeflags} 2>&1" > /dev/null
  if test $? -eq 0; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi
testing="postfix make args (make_install)"
cmp_makeflags="`echo ${cmp_makeflags} | sed -e 's:\ball-:install-:g'`"
if test x"${cmp_makeflags}" = x; then
  untested "${testing}" #implies that the config for this tool no longer contains default_makeflags
else
  out="`. ${topdir}/config/${tool}.conf && make_install ${tool}.git 2>&1`"
  if test x"${debug}" = x"yes"; then
    echo "${out}"
  fi
  echo "${out}" | grep -- "${cmp_makeflags} 2>&1" > /dev/null
  if test $? -eq 0; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi
cmp_makeflags=

testing="configure"
tool="dejagnu"
configure="`grep ^configure= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
if test x"${configure}" = xno; then
  untested "${testing}"
else
  out=`configure_build ${tool}.git 2>&1`
  if test x"${debug}" = x"yes"; then
    echo "${out}"
  fi
  echo "${out}" | grep -- '^DRYRUN: .*/configure ' > /dev/null
  if test $? -eq 0; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi
testing="copy instead of configure"
tool="eembc"
configure="`grep ^configure= ${topdir}/config/${tool}.conf | cut -d '\"' -f 2`"
if test \! x"${configure}" = xno; then
  untested "${testing}" #implies that the tool's config no longer contains configure, or that it has a wrong value
elif test x"${configure}" = xno; then
  out=`configure_build ${tool}.git 2>&1`
  if test x"${debug}" = x"yes"; then
    echo "${out}"
  fi
  echo "${out}" | grep -- '^DRYRUN: rsync -a --exclude=.git/ .\+/ ' > /dev/null
  if test $? -eq 0; then
    pass "${testing}"
  else
    fail "${testing}"
  fi
fi
dryrun="no"

testing="dryrun quote preservation (dryrun=no)"
out=`dryrun 'echo "enquoted"'`
if test x"${out}" = $'xRUN: echo "enquoted"\nenquoted'; then
  pass "${testing}"
else
  fail "${testing}"
fi
dryrun="yes"
testing="dryrun quote preservation (dryrun=yes)"
out=`dryrun 'echo "enquoted"' 2>&1`
if test x"${out}" = 'xDRYRUN: echo "enquoted"'; then
  pass "${testing}"
else
  fail "${testing}"
fi
dryrun="no"

# TODO: Test checkout directly with a non URL.
# TODO: Test checkout with a multi-/ branch

#testing="checkout: http://git@<url>/<repo>.git~multi/part/branch."
#if test ! -e "${PWD}/host.conf"; then
#   package="glibc.git"
#   branch='release/2.18/master'
#   revision=""
#   should="pass"
#   test_checkout "${should}" "${testing}" "${package}" "${branch}" "${revision}"
#else
#    untested "${testing}"
#fi

. "${topdir}/testsuite/srcdir-tests.sh"

# ----------------------------------------------------------------------------------
# print the total of test results
totals

