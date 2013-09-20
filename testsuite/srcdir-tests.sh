# tests for the get_srcdir() function

echo "============= get_srcdir() tests ================"

# FIXME: Note these following test cases only PASS if you have the source
# directories created already.
if test -d ${local_snapshots}/gcc.git; then
    in="git://git.linaro.org/toolchain/gcc.git"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc.git"; then
	pass "get_srcdir: git repository"
    else
	fail "get_srcdir: git repository"
	fixme "get_srcdir returned ${out}"
    fi
else
    untested  "get_srcdir: git repository"
fi

if test -d ${local_snapshots}/gcc.git-linaro-4.8-branch; then
    in="git://git.linaro.org/toolchain/gcc.git/linaro-4.8-branch"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc.git-linaro-4.8-branch/gcc-4_8-branch"; then
	pass "get_srcdir: git repository with branch"
    else
	fail "get_srcdir: git repository with branch"
	fixme "get_srcdir returned ${out}"
    fi
else
    untested "get_srcdir: git repository with branch"
fi

if test -d ${local_snapshots}/gcc.git-linaro-4.8-branch@123456; then
    in="git://git.linaro.org/toolchain/gcc.git/linaro-4.8-branch@123456"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc.git-linaro-4.8-branch@123456/gcc-4_8-branch"; then
	pass "get_srcdir: git repository with branch and commit"
    else
	fail "get_srcdir: git repository with branch and commit"
	fixme "get_srcdir returned ${out}"
    fi
else
    untested "get_srcdir: git repository with branch and commit"
fi

if test -d ${local_snapshots}/gcc-linaro-4.8-2013.06-1; then
    in="gcc-linaro-4.8-2013.06-1.tar.xz"
    out="`get_srcdir $in | grep -v TRACE`"
    if test x"${out}" = x"${local_snapshots}/gcc-linaro-4.8-2013.06-1"; then
	pass "get_srcdir: with tarball"
    else
	fail "get_srcdir: with tarball"
	fixme "get_srcdir returned ${out}"
    fi
else
    untested "get_srcdir: with tarball"
fi
