#!/bin/bash

set -xeu

# Common Variables
OSNAME=$(uname -s)
ROOT="$PWD"

# OS-Dependent Configurations
if [ "$OSNAME" == "Darwin" ]; then
    GETOPT="/opt/homebrew/opt/gnu-getopt/bin/getopt"
    TCLSH="/opt/homebrew/opt/tcl-tk/bin/tclsh"
    M4="/opt/homebrew/opt/m4/bin/m4"
    ACLOCAL_1_15_HOST="/opt/automake-1.15/bin/aclocal"
    AUTOMAKE_1_15_HOST="/opt/automake-1.15/bin/automake"
    AUTOCONF_2_69_HOST="/opt/autoconf-2.69/bin/autoconf"
    AUTORECONF_2_69_HOST="/opt/autoconf-2.69/bin/autoreconf"
    SED_TYPE="bsd"
else
    GETOPT="$(which getopt)"
    TCLSH="$(which tclsh)"
    M4="$(which m4)"
    # TODO: use proper search method
    ACLOCAL_1_15_HOST="/opt/automake-1.15/bin/aclocal"
    AUTOMAKE_1_15_HOST="/opt/automake-1.15/bin/automake"
    AUTOCONF_2_69_HOST="/opt/autoconf-2.69/bin/autoconf"
    AUTORECONF_2_69_HOST="/opt/autoconf-2.69/bin/autoreconf"
    SED_TYPE="gnu"
fi
ACLOCAL_HOST="$(which aclocal)"
AUTOMAKE_HOST="$(which automake)"
AUTOCONF_HOST="$(which autoconf)"
AUTORECONF_HOST="$(which autoreconf)"
AUTOHEADER_HOST="$(which autoheader)"


# Option Variables
ARCHIVE_NAME="folisdk.tar.gz"
ARCH_LIST=x86_64
declare -a ARCHS
PREFIX=
PARALLEL=
BUILDDIR=$ROOT/build


# Parse arguments
GETOPT_OUTPUT=$("$GETOPT" -o "a:b:hj:o:p:" --long "arch:,build-dir:,help,jobs:,output:,prefix:" --name "$(basename "$0")" -- "$@")

if [ $? != 0 ]; then
    exit 1
fi

eval set -- "$GETOPT_OUTPUT"

while :; do
    case "$1" in
        -h | --help)
            echo "Usage: $(basename "$0") [options]"
            echo "Options:"
            echo "  -a, --arch <arch>[,...]       Set the target architecture"
            echo "  -b, --build-dir <path>        Set the build directory"
            echo "  -j, --jobs <number>           Set the number of jobs"
            echo "  -p, --prefix <path>           Set the prefix directory"
            exit 0
            ;;
        -b | --build-dir)
            BUILDDIR="$2"
            shift 2
            ;;
        -o | --output)
            ARCHIVE_NAME="$2"
            shift 2
            ;;
        -p | --prefix)
            PREFIX="$2"
            shift 2
            ;;
        -a | --arch)
            ARCH_LIST="$2"
            shift 2
            ;;
        -j | --jobs)
            PARALLEL="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
    esac
done

IFS="," read -r -a ARCHS <<< "$ARCH_LIST"


# Default Options
if [ -z "$PREFIX" ]; then
    if [ "$OSNAME" == "Darwin" ]; then
        PREFIX="/opt/homebrew/opt/folisdk"
    else
        PREFIX="/opt/folisdk"
    fi
fi

if [ -z "$PARALLEL" ]; then
    if [ "$OSNAME" == "Darwin" ]; then
        PROCCOUNT=$(sysctl -n hw.ncpu)
    else
        PROCCOUNT=$(nproc)
    fi
    PARALLEL=$((PROCCOUNT > 1 ? PROCCOUNT - 1 : 1))
fi


# macOS Workarounds
if [ "$OSNAME" == "Darwin" ]; then
    export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
    export MAKEINFO=/opt/homebrew/bin/makeinfo
fi


# Library Version Configs
source versions.cfg


# Helper Functions
start_section() {
    if [ "${GITHUB_ACTIONS:-false}" == "true" ]; then
        echo "::group::$1"
    else
        echo "=== $1 ==="
    fi
}

end_section() {
    if [ "${GITHUB_ACTIONS:-false}" == "true" ]; then
        echo "::endgroup::"
    fi
}


# Global Build Settings
PKGBUILDDIR="$BUILDDIR/pkgroot"
mkdir -p "$PKGBUILDDIR"

export M4="$M4"
export PATH="$PKGBUILDDIR/$PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export CPPFLAGS="-I$PKGBUILDDIR/$PREFIX/include"
export LDFLAGS="-L$PKGBUILDDIR/$PREFIX/lib"
unset LD_LIBRARY_PATH
unset DYLD_LIBRARY_PATH
unset C_INCLUDE_PATH
unset CPLUS_INCLUDE_PATH
unset LIBRARY_PATH

# Global Builds
if [ ! -f "$BUILDDIR/.download-sources.stamp" ]; then
    cd "$BUILDDIR"

    git clone https://git.savannah.gnu.org/git/gnulib.git --depth 1

    curl --retry 5 --retry-delay 2 -ZL \
        -o "pkg-config-$PKGCONFIG_VERSION.tar.gz" "$PKGCONFIG_URL" \
        -o "gmp-$GMP_VERSION.tar.xz" "$GMP_URL" \
        -o "mpfr-$MPFR_VERSION.tar.xz" "$MPFR_URL" \
        -o "mpc-$MPC_VERSION.tar.gz" "$MPC_URL" \
        -o "isl-$ISL_VERSION.tar.gz" "$ISL_URL" \
        -o "nettle-$NETTLE_VERSION.tar.gz" "$NETTLE_URL" \
        -o "libsodium-$LIBSODIUM_VERSION.tar.gz" "$LIBSODIUM_URL" \
        -o "libffi-$LIBFFI_VERSION.tar.gz" "$LIBFFI_URL" \
        -o "libuv-v$LIBUV_VERSION.tar.gz" "$LIBUV_URL" \
        -o "libxml2-$LIBXML2_VERSION.tar.xz" "$LIBXML2_URL" \
        -o "libxslt-$LIBXSLT_VERSION.tar.xz" "$LIBXSLT_URL" \
        -o "expat-$LIBEXPAT_VERSION.tar.xz" "$LIBEXPAT_URL" \
        -o "yyjson-$YYJSON_VERSION.tar.gz" "$YYJSON_URL" \
        -o "zlib-$ZLIB_VERSION.tar.gz" "$ZLIB_URL" \
        -o "bzip2-$BZIP2_VERSION.tar.gz" "$BZIP2_URL" \
        -o "xz-$XZ_VERSION.tar.gz" "$XZ_URL" \
        -o "lz4-$LZ4_VERSION.tar.gz" "$LZ4_URL" \
        -o "zstd-$ZSTD_VERSION.tar.gz" "$ZSTD_URL" \
        -o "libarchive-$LIBARCHIVE_VERSION.tar.gz" "$LIBARCHIVE_URL" \
        -o "libiconv-$LIBICONV_VERSION.tar.gz" "$LIBICONV_URL" \
        -o "ncurses-$NCURSES_VERSION.tar.gz" "$NCURSES_URL" \
        -o "editline-$EDITLINE_VERSION.tar.gz" "$EDITLINE_URL" \
        -o "readline-$READLINE_VERSION.tar.gz" "$READLINE_URL" \
        -o "sqlite-autoconf-$SQLITE3_VERSION.tar.gz" "$SQLITE3_URL"

    touch "$BUILDDIR/.download-sources.stamp"
fi

if [ ! -f "$BUILDDIR/.extract-sources.stamp" ]; then
    cd "$BUILDDIR"

    # pkgconfig
    rm -rf pkgconfig-src
    tar -xf "pkg-config-$PKGCONFIG_VERSION.tar.gz"
    mv "pkg-config-$PKGCONFIG_VERSION" pkgconfig-src

    # gmp
    rm -rf gmp-src
    tar -xf "gmp-$GMP_VERSION.tar.xz"
    mv "gmp-$GMP_VERSION" gmp-src

    # mpfr
    rm -rf mpfr-src
    tar -xf "mpfr-$MPFR_VERSION.tar.xz"
    mv "mpfr-$MPFR_VERSION" mpfr-src

    # mpc
    rm -rf mpc-src
    tar -xf "mpc-$MPC_VERSION.tar.gz"
    mv "mpc-$MPC_VERSION" mpc-src

    # isl
    rm -rf isl-src
    tar -xf "isl-$ISL_VERSION.tar.gz"
    mv "isl-$ISL_VERSION" isl-src

    # nettle
    rm -rf nettle-src
    tar -xf "nettle-$NETTLE_VERSION.tar.gz"
    mv "nettle-$NETTLE_VERSION" nettle-src

    # libsodium
    rm -rf libsodium-src
    tar -xf "libsodium-$LIBSODIUM_VERSION.tar.gz"
    mv "libsodium-$LIBSODIUM_VERSION" libsodium-src

    # libffi
    rm -rf libffi-src
    tar -xf "libffi-$LIBFFI_VERSION.tar.gz"
    mv "libffi-$LIBFFI_VERSION" libffi-src

    # libuv
    rm -rf libuv-src
    tar -xf "libuv-v$LIBUV_VERSION.tar.gz"
    mv "libuv-v$LIBUV_VERSION" libuv-src

    # libxml2
    rm -rf libxml2-src
    tar -xf "libxml2-$LIBXML2_VERSION.tar.xz"
    mv "libxml2-$LIBXML2_VERSION" libxml2-src

    # libxslt
    rm -rf libxslt-src
    tar -xf "libxslt-$LIBXSLT_VERSION.tar.xz"
    mv "libxslt-$LIBXSLT_VERSION" libxslt-src

    # libexpat
    rm -rf libexpat-src
    tar -xf "expat-$LIBEXPAT_VERSION.tar.xz"
    mv "expat-$LIBEXPAT_VERSION" libexpat-src

    # yyjson
    rm -rf yyjson-src
    tar -xf "yyjson-$YYJSON_VERSION.tar.gz"
    mv "yyjson-$YYJSON_VERSION" yyjson-src

    # zlib
    rm -rf zlib-src
    tar -xf "zlib-$ZLIB_VERSION.tar.gz"
    mv "zlib-$ZLIB_VERSION" zlib-src

    # bzip2
    rm -rf bzip2-src
    tar -xf "bzip2-$BZIP2_VERSION.tar.gz"
    mv "bzip2-$BZIP2_VERSION" bzip2-src

    # xz
    rm -rf xz-src
    tar -xf "xz-$XZ_VERSION.tar.gz"
    mv "xz-$XZ_VERSION" xz-src

    # lz4
    rm -rf lz4-src
    tar -xf "lz4-$LZ4_VERSION.tar.gz"
    mv "lz4-$LZ4_VERSION" lz4-src

    # zstd
    rm -rf zstd-src
    tar -xf "zstd-$ZSTD_VERSION.tar.gz"
    mv "zstd-$ZSTD_VERSION" zstd-src

    # libarchive
    rm -rf libarchive-src
    tar -xf "libarchive-$LIBARCHIVE_VERSION.tar.gz"
    mv "libarchive-$LIBARCHIVE_VERSION" libarchive-src

    # libiconv
    rm -rf libiconv-src
    tar -xf "libiconv-$LIBICONV_VERSION.tar.gz"
    mv "libiconv-$LIBICONV_VERSION" libiconv-src

    # ncurses
    rm -rf ncurses-src
    tar -xf "ncurses-$NCURSES_VERSION.tar.gz"
    mv "ncurses-$NCURSES_VERSION" ncurses-src

    # editline
    rm -rf editline-src
    tar -xf "editline-$EDITLINE_VERSION.tar.gz"
    mv "editline-$EDITLINE_VERSION" editline-src

    # readline
    rm -rf readline-src
    tar -xf "readline-$READLINE_VERSION.tar.gz"
    mv "readline-$READLINE_VERSION" readline-src

    # sqlite3
    rm -rf sqlite3-src
    tar -xf "sqlite-autoconf-$SQLITE3_VERSION.tar.gz"
    DIRNAME=$(tar -tf "sqlite-autoconf-$SQLITE3_VERSION.tar.gz" | head -1 | cut -f1 -d"/")
    mv "$DIRNAME" sqlite3-src

    touch "$BUILDDIR/.extract-sources.stamp"
fi

if [ ! -f "$BUILDDIR/.preconfigure-libtool.stamp" ]; then
    start_section "Pre-Configure libtool"
    cd "$ROOT/libtool-strata"
    git clean -fdX
    echo "2.5.4" > .tarball-version
    echo "2.5.4" > .version
    echo "4442" > .serial
    OLD_PATH="$PATH"
    if [ "$OSNAME" == "Darwin" ]; then
        export PATH="$PATH:/opt/homebrew/bin"
    fi
    ./bootstrap --gnulib-srcdir="$BUILDDIR/gnulib" --skip-git --verbose
    export PATH="$OLD_PATH"
    end_section

    touch "$BUILDDIR/.preconfigure-libtool.stamp"
fi  

if [ ! -f "$BUILDDIR/.configure-libtool.stamp" ]; then
    mkdir -p "$BUILDDIR/libtool"
    cd "$BUILDDIR/libtool"

    start_section "Configure libtool"
    ../../libtool-strata/configure \
        --prefix="$PKGBUILDDIR/$PREFIX" \
        --disable-ltdl-install
    end_section

    touch "$BUILDDIR/.configure-libtool.stamp"
fi

if [ ! -f "$BUILDDIR/.build-libtool.stamp" ]; then
    cd "$BUILDDIR/libtool"

    start_section "Make libtool"
    OLD_PATH="$PATH"
    if [ "$OSNAME" == "Darwin" ]; then
        export PATH="$PATH:/opt/homebrew/bin"
    fi
    make -j"$PARALLEL"
    export PATH="$OLD_PATH"
    end_section

    start_section "Install libtool"
    make install
    end_section

    touch "$BUILDDIR/.build-libtool.stamp"
fi

export LIBTOOL="$PKGBUILDDIR/$PREFIX/bin/libtool"
export LIBTOOLIZE="$PKGBUILDDIR/$PREFIX/bin/libtoolize"

if [ ! -f "$BUILDDIR/.patch-gnulib.stamp" ]; then
    start_section "Patch gnulib"
    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/gnulib/build-aux"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/gnulib/build-aux"
    end_section

    touch "$BUILDDIR/.patch-gnulib.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-gmp.stamp" ]; then
    cd "$BUILDDIR/gmp-src"

    start_section "Patch gmp"
    patch -p1 < "$ROOT/patches/gmp-$GMP_VERSION.patch"

    ACLOCAL="true" \
    AUTOMAKE="$AUTOMAKE_1_15_HOST" \
    AUTOCONF="$AUTOCONF_2_69_HOST" \
    "$AUTORECONF_2_69_HOST"

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/gmp-src"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/gmp-src"
    end_section

    touch "$BUILDDIR/.patch-gmp.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-mpfr.stamp" ]; then
    cd "$BUILDDIR/mpfr-src"

    start_section "Patch mpfr"
    "$LIBTOOLIZE" --force --copy

    ACLOCAL="$ACLOCAL_HOST" \
    AUTOMAKE="$AUTOMAKE_HOST" \
    AUTOCONF="$AUTOCONF_HOST" \
    "$AUTORECONF_HOST" -ivf

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/mpfr-src"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/mpfr-src"
    end_section

    touch "$BUILDDIR/.patch-mpfr.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-mpc.stamp" ]; then
    cd "$BUILDDIR/mpc-src"

    start_section "Patch mpc"
    "$LIBTOOLIZE" --force --copy

    ACLOCAL="$ACLOCAL_1_15_HOST -I $PKGBUILDDIR/$PREFIX/share/aclocal" \
    AUTOMAKE="$AUTOMAKE_1_15_HOST" \
    AUTOCONF="$AUTOCONF_2_69_HOST" \
    "$AUTORECONF_2_69_HOST" -ivf

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/mpc-src/build-aux"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/mpc-src/build-aux"
    end_section

    touch "$BUILDDIR/.patch-mpc.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-nettle.stamp" ]; then
    cd "$BUILDDIR/nettle-src"

    start_section "Patch nettle"
    patch -p1 < "$ROOT/patches/nettle-$NETTLE_VERSION.patch"

    ACLOCAL="true" \
    AUTOMAKE="$AUTOMAKE_1_15_HOST" \
    AUTOCONF="$AUTOCONF_2_69_HOST" \
    "$AUTORECONF_2_69_HOST"

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/nettle-src"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/nettle-src"
    end_section

    touch "$BUILDDIR/.patch-nettle.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-libsodium.stamp" ]; then
    cd "$BUILDDIR/libsodium-src"
    
    start_section "Patch libsodium"
    "$LIBTOOLIZE" --force --copy

    ACLOCAL="$ACLOCAL_HOST" \
    AUTOMAKE="$AUTOMAKE_HOST" \
    AUTOCONF="$AUTOCONF_HOST" \
    "$AUTORECONF_HOST" -ivf

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libsodium-src/build-aux"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libsodium-src/build-aux"
    end_section

    touch "$BUILDDIR/.patch-libsodium.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-libffi.stamp" ]; then
    cd "$BUILDDIR/libffi-src"

    start_section "Patch libffi"
    "$LIBTOOLIZE" --force --copy

    ACLOCAL="$ACLOCAL_HOST" \
    AUTOMAKE="$AUTOMAKE_HOST" \
    AUTOCONF="$AUTOCONF_HOST" \
    "$AUTORECONF_HOST" -ivf

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libffi-src"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libffi-src"
    end_section

    touch "$BUILDDIR/.patch-libffi.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-libuv.stamp" ]; then
    cd "$BUILDDIR/libuv-src"

    start_section "Patch libuv"
    OLD_PATH="$PATH"
    if [ "$OSNAME" == "Darwin" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
    fi
    ./autogen.sh
    export PATH="$OLD_PATH"

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libuv-src"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libuv-src"
    end_section

    touch "$BUILDDIR/.patch-libuv.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-libxml2.stamp" ]; then
    cd "$BUILDDIR/libxml2-src"
    
    start_section "Patch libxml2"
    "$LIBTOOLIZE" --force --copy

    OLD_PATH="$PATH"
    if [ "$OSNAME" == "Darwin" ]; then
        export PATH="$PATH:/opt/homebrew/bin"
    fi
    ACLOCAL="$ACLOCAL_HOST" \
    AUTOMAKE="$AUTOMAKE_HOST" \
    AUTOCONF="$AUTOCONF_HOST" \
    AUTORECONF="$AUTORECONF_HOST" \
    NOCONFIGURE="true" \
    ./autogen.sh
    export PATH="$OLD_PATH"

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libxml2-src"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libxml2-src"
    end_section

    touch "$BUILDDIR/.patch-libxml2.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-libxslt.stamp" ]; then
    cd "$BUILDDIR/libxslt-src"

    start_section "Patch libxslt"
    "$LIBTOOLIZE" --force --copy

    ACLOCAL="$ACLOCAL_HOST" \
    AUTOMAKE="$AUTOMAKE_HOST" \
    AUTOCONF="$AUTOCONF_HOST" \
    "$AUTORECONF_HOST" -ivf

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libxslt-src"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libxslt-src"
    end_section

    touch "$BUILDDIR/.patch-libxslt.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-libexpat.stamp" ]; then
    cd "$BUILDDIR/libexpat-src"

    start_section "Patch libexpat"
    "$LIBTOOLIZE" --force --copy

    ACLOCAL="$ACLOCAL_HOST" \
    AUTOMAKE="$AUTOMAKE_HOST" \
    AUTOCONF="$AUTOCONF_HOST" \
    "$AUTORECONF_HOST" -ivf

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libexpat-src/conftools"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libexpat-src/conftools"
    end_section

    touch "$BUILDDIR/.patch-libexpat.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-zlib.stamp" ]; then
    cd "$BUILDDIR/zlib-src"

    start_section "Patch zlib"
    patch -p1 < "$ROOT/patches/zlib-$ZLIB_VERSION.patch"
    end_section

    touch "$BUILDDIR/.patch-zlib.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-bzip2.stamp" ]; then
    cd "$BUILDDIR/bzip2-src"

    start_section "Patch bzip2"
    patch -p1 < "$ROOT/patches/bzip2-$BZIP2_VERSION.patch"
    end_section

    touch "$BUILDDIR/.patch-bzip2.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-xz.stamp" ]; then
    cd "$BUILDDIR/xz-src"

    start_section "Patch xz"
    "$LIBTOOLIZE" --force --copy

    OLD_PATH="$PATH"
    if [ "$OSNAME" == "Darwin" ]; then
        export PATH="$PATH:/opt/homebrew/bin"
    fi
    ACLOCAL="$ACLOCAL_HOST" \
    AUTOMAKE="$AUTOMAKE_HOST" \
    AUTOCONF="$AUTOCONF_HOST" \
    "$AUTORECONF_HOST" -ivf
    export PATH="$OLD_PATH"

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/xz-src/build-aux"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/xz-src/build-aux"
    end_section

    touch "$BUILDDIR/.patch-xz.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-lz4.stamp" ]; then
    cd "$BUILDDIR/lz4-src"

    start_section "Patch lz4"
    patch -p1 < "$ROOT/patches/lz4-$LZ4_VERSION.patch"
    end_section

    touch "$BUILDDIR/.patch-lz4.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-zstd.stamp" ]; then
    cd "$BUILDDIR/zstd-src"

    start_section "Patch zstd"
    patch -p1 < "$ROOT/patches/zstd-$ZSTD_VERSION.patch"
    end_section

    touch "$BUILDDIR/.patch-zstd.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-libarchive.stamp" ]; then
    cd "$BUILDDIR/libarchive-src"

    start_section "Patch libarchive"
    "$LIBTOOLIZE" --force --copy

    ACLOCAL="$ACLOCAL_HOST" \
    AUTOMAKE="$AUTOMAKE_HOST" \
    AUTOCONF="$AUTOCONF_HOST" \
    "$AUTORECONF_HOST" -ivf

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libarchive-src/build/autoconf"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libarchive-src/build/autoconf"
    if [ "$SED_TYPE" == "bsd" ]; then
        sed -i '' \
            's/hmac_sha1_digest(ctx, (unsigned)\*out_len, out)/hmac_sha1_digest(ctx, out)/g' \
            "$BUILDDIR/libarchive-src/libarchive/archive_hmac.c"
    else
        sed -i \
            's/hmac_sha1_digest(ctx, (unsigned)\*out_len, out)/hmac_sha1_digest(ctx, out)/g' \
            "$BUILDDIR/libarchive-src/libarchive/archive_hmac.c"
    fi
    end_section

    touch "$BUILDDIR/.patch-libarchive.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-libiconv.stamp" ]; then
    start_section "Patch libiconv"
    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libiconv-src/build-aux"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libiconv-src/build-aux"
    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/libiconv-src/libcharset/build-aux"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/libiconv-src/libcharset/build-aux"
    end_section

    touch "$BUILDDIR/.patch-libiconv.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-ncurses.stamp" ]; then
    cd "$BUILDDIR/ncurses-src"

    start_section "Patch ncurses"
    "$LIBTOOLIZE" --force --copy
    
    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/ncurses-src"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/ncurses-src"
    end_section

    touch "$BUILDDIR/.patch-ncurses.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-editline.stamp" ]; then
    cd "$BUILDDIR/editline-src"

    start_section "Patch editline"
    "$LIBTOOLIZE" --force --copy

    ACLOCAL="$ACLOCAL_1_15_HOST" \
    AUTOMAKE="$AUTOMAKE_1_15_HOST" \
    AUTOCONF="$AUTOCONF_2_69_HOST" \
    "$AUTORECONF_2_69_HOST" -ivf

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/editline-src/aux"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/editline-src/aux"
    end_section

    touch "$BUILDDIR/.patch-editline.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-readline.stamp" ]; then
    cd "$BUILDDIR/readline-src"

    start_section "Patch readline"
    patch -p1 < "$ROOT/patches/readline-$READLINE_VERSION.patch"

    cp "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/readline-src/support"
    cp "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/readline-src/support"
    end_section

    touch "$BUILDDIR/.patch-readline.stamp"
fi

if [ ! -f "$BUILDDIR/.patch-sqlite3.stamp" ]; then
    start_section "Patch sqlite3"
    cp -f "$ROOT/gnu-config-strata/config.sub" "$BUILDDIR/sqlite3-src/autosetup/autosetup-config.sub"
    cp -f "$ROOT/gnu-config-strata/config.guess" "$BUILDDIR/sqlite3-src/autosetup/autosetup-config.guess"
    end_section

    touch "$BUILDDIR/.patch-sqlite3.stamp"
fi

if [ ! -f "$BUILDDIR/.configure-pkgconfig.stamp" ]; then
    mkdir -p "$BUILDDIR/pkgconfig"
    cd "$BUILDDIR/pkgconfig"

    start_section "Configure pkgconfig"
    CFLAGS="-Wno-error=int-conversion" \
    ../pkgconfig-src/configure \
        --prefix="$PKGBUILDDIR/$PREFIX" \
        --with-internal-glib \
        --disable-host-tool \
        --disable-debug
    end_section

    touch "$BUILDDIR/.configure-pkgconfig.stamp"
fi

if [ ! -f "$BUILDDIR/.build-pkgconfig.stamp" ]; then
    cd "$BUILDDIR/pkgconfig"

    start_section "Make pkgconfig"
    make -j"$PARALLEL"
    end_section

    start_section "Install pkgconfig"
    make install
    end_section

    touch "$BUILDDIR/.build-pkgconfig.stamp"
fi

if [ ! -f "$BUILDDIR/.configure-zlib.stamp" ]; then
    mkdir -p "$BUILDDIR/zlib"
    cd "$BUILDDIR/zlib"

    start_section "Configure zlib"
    ../zlib-src/configure --prefix="$PREFIX" --static
    end_section

    touch "$BUILDDIR/.configure-zlib.stamp"
fi

if [ ! -f "$BUILDDIR/.build-zlib.stamp" ]; then
    cd "$BUILDDIR/zlib"

    start_section "Make zlib"
    make -j"$PARALLEL"
    end_section

    start_section "Install zlib"
    make install DESTDIR="$PKGBUILDDIR"
    end_section

    touch "$BUILDDIR/.build-zlib.stamp"
fi

if [ ! -f "$BUILDDIR/.configure-ncurses.stamp" ]; then
    mkdir -p "$BUILDDIR/ncurses"
    cd "$BUILDDIR/ncurses"

    start_section "Configure ncurses"
    CC=gcc \
    CFLAGS="-O2 -Wno-implicit-int -Wno-return-type" \
    ../ncurses-src/configure \
        --without-shared \
        --without-debug \
        --without-ada \
        --without-cxx \
        --without-manpages \
        --without-tests \
        --disable-mixed-case \
        --enable-widec
    end_section

    touch "$BUILDDIR/.configure-ncurses.stamp"
fi

if [ ! -f "$BUILDDIR/.build-ncurses.stamp" ]; then
    cd "$BUILDDIR/ncurses"

    start_section "Make ncurses"
    make -j"$PARALLEL" -C include
    make -j"$PARALLEL" -C ncurses
    make -j"$PARALLEL" -C progs tic
    end_section

    touch "$BUILDDIR/.build-ncurses.stamp"
fi

export TIC="$BUILDDIR/ncurses/progs/tic"

if [ ! -f "$BUILDDIR/.configure-cmake.stamp" ]; then
    mkdir -p "$BUILDDIR/cmake"
    cd "$BUILDDIR/cmake"

    start_section "Configure cmake"
    ../../cmake-strata/bootstrap --prefix="$PREFIX" --parallel="$PARALLEL"
    end_section

    touch "$BUILDDIR/.configure-cmake.stamp"
fi

if [ ! -f "$BUILDDIR/.build-cmake.stamp" ]; then
    cd "$BUILDDIR/cmake"

    start_section "Make cmake"
    make -j"$PARALLEL"
    end_section

    start_section "Install cmake"
    make install DESTDIR="$PKGBUILDDIR"
    end_section

    touch "$BUILDDIR/.build-cmake.stamp"
fi

export CMAKE="$PKGBUILDDIR/$PREFIX/bin/cmake"
export CCMAKE="$PKGBUILDDIR/$PREFIX/bin/ccmake"
export CTEST="$PKGBUILDDIR/$PREFIX/bin/ctest"
export CPACK="$PKGBUILDDIR/$PREFIX/bin/cpack"

if [ ! -f "$BUILDDIR/.configure-sidlc.stamp" ]; then
    mkdir -p "$BUILDDIR/sidlc"
    cd "$BUILDDIR/sidlc"

    start_section "Configure sidlc"
    "$CMAKE" -S../../sidlc -B. \
        -DCMAKE_INSTALL_PREFIX="$PREFIX"
    end_section

    touch "$BUILDDIR/.configure-sidlc.stamp"
fi

if [ ! -f "$BUILDDIR/.build-sidlc.stamp" ]; then
    cd "$BUILDDIR/sidlc"

    start_section "Make sidlc"
    "$CMAKE" --build . --parallel="$PARALLEL"
    end_section

    start_section "Install sidlc"
    DESTDIR="$PKGBUILDDIR" \
    "$CMAKE" --install .
    end_section

    touch "$BUILDDIR/.build-sidlc.stamp"
fi

unset LIBTOOL
unset LIBTOOLIZE

ROOT_PATH="$PATH"
ROOT_CPPFLAGS="$CPPFLAGS"
ROOT_LDFLAGS="$LDFLAGS"

BUILD_TRIPLET=$("$ROOT/gnu-config-strata/config.guess")

for ARCH in "${ARCHS[@]}"; do
    # Per-Target Build Settings
    TARGET_TRIPLET="$ARCH-strata-folios"
    SYSROOT="$PREFIX/$TARGET_TRIPLET/sysroot"

    export PATH="$ROOT_PATH"
    export PKG_CONFIG_PATH=""
    export PKG_CONFIG_LIBDIR="$PKGBUILDDIR/$PREFIX/lib/pkgconfig:$PKGBUILDDIR/$PREFIX/share/pkgconfig"
    export PKG_CONFIG_SYSROOT_DIR="$PKGBUILDDIR/$PREFIX"
    unset CPPFLAGS
    unset LDFLAGS
    unset PKG_CONFIG_ALLOW_SYSTEM_CFLAGS
    unset PKG_CONFIG_ALLOW_SYSTEM_LIBS

    mkdir -p "$PKGBUILDDIR/$SYSROOT"
    
    # Per-Target Builds
    if [ ! -f "$BUILDDIR/.configure-binutils-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/binutils-$ARCH"
        cd "$BUILDDIR/binutils-$ARCH"

        start_section "Configure binutils"
        CFLAGS="$ROOT_CPPFLAGS" \
        CXXFLAGS="$ROOT_CPPFLAGS" \
        LDFLAGS="$ROOT_LDFLAGS -s" \
        ../../binutils-strata/configure \
            --build="$BUILD_TRIPLET" \
            --target="$TARGET_TRIPLET" \
            --prefix="$PREFIX" \
            --with-build-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --with-sysroot="$SYSROOT" \
            --disable-nls \
            --disable-werror \
            --enable-static \
            --with-system-zlib
        end_section

        touch "$BUILDDIR/.configure-binutils-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-binutils-$ARCH.stamp" ]; then
        cd "$BUILDDIR/binutils-$ARCH"

        start_section "Make binutils"
        make -j"$PARALLEL"
        end_section

        start_section "Install binutils"
        make install DESTDIR="$PKGBUILDDIR"
        end_section

        touch "$BUILDDIR/.build-binutils-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-gcc-pass1-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/gcc-pass1-$ARCH"
        cd "$BUILDDIR/gcc-pass1-$ARCH"

        start_section "Configure GCC (pass1)"
        CFLAGS="$ROOT_CPPFLAGS" \
        CXXFLAGS="$ROOT_CPPFLAGS" \
        LDFLAGS="$ROOT_LDFLAGS -s" \
        ../../gcc-strata/configure \
            --build="$BUILD_TRIPLET" \
            --target="$TARGET_TRIPLET" \
            --prefix="$PREFIX" \
            --with-sysroot="$SYSROOT" \
            --with-native-system-header-dir="/usr/include" \
            --with-system-zlib \
            --with-newlib \
            --without-headers \
            --enable-languages=c \
            --disable-nls \
            --disable-libssp \
            --disable-threads \
            --disable-shared \
            --disable-libgomp \
            --disable-libquadmath \
            --disable-libatomic \
            --disable-lto
        end_section

        touch "$BUILDDIR/.configure-gcc-pass1-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-gcc-pass1-$ARCH.stamp" ]; then
        cd "$BUILDDIR/gcc-pass1-$ARCH"

        start_section "Make GCC (pass1)"
        make -j"$PARALLEL" all-gcc
        end_section

        start_section "Make GCC (pass1) - libgcc"
        make -j"$PARALLEL" all-target-libgcc
        end_section

        start_section "Install GCC (pass1)"
        make install-gcc DESTDIR="$PKGBUILDDIR"
        end_section

        start_section "Install GCC (pass1) - libgcc"
        make install-target-libgcc DESTDIR="$PKGBUILDDIR"
        end_section

        touch "$BUILDDIR/.build-gcc-pass1-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-musl-pass1-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/musl-pass1-$ARCH"
        cd "$BUILDDIR/musl-pass1-$ARCH"

        start_section "Configure musl libc (pass1)"
        CROSS_COMPILE="$TARGET_TRIPLET-" \
        ../../musl-strata/configure \
            --build="$BUILD_TRIPLET" \
            --target="$TARGET_TRIPLET" \
            --with-sysroot="$SYSROOT" \
            --prefix="/usr" \
            --disable-shared \
            --disable-gcc-wrapper
        end_section

        touch "$BUILDDIR/.configure-musl-pass1-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-musl-pass1-$ARCH.stamp" ]; then
        cd "$BUILDDIR/musl-pass1-$ARCH"

        start_section "Install musl libc (pass1) - headers"
        make install-headers DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        start_section "Make musl libc (pass1)"
        make -j"$PARALLEL"
        end_section

        start_section "Install musl libc (pass1)"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-musl-pass1-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libtool-pass1-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libtool-pass1-$ARCH"
        cd "$BUILDDIR/libtool-pass1-$ARCH"

        start_section "Configure libtool (pass1)"
        OLD_PATH="$PATH"
        if [ "$OSNAME" == "Darwin" ]; then
            export PATH="$PATH:/opt/homebrew/bin"
        fi
        CC="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-gcc" \
        CXX="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-gcc" \
        AR="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-ld -r -o" \
        NM="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-nm" \
        AS="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-as" \
        LD="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-ld" \
        STRIP="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-strip" \
        RANLIB="true" \
        ../../libtool-strata/configure \
            --build="$BUILD_TRIPLET" \
            --prefix="$PKGBUILDDIR/$PREFIX" \
            --exec-prefix="$PKGBUILDDIR/$PREFIX/$TARGET_TRIPLET" \
            --host="$TARGET_TRIPLET" \
            --enable-ltdl-install \
            --enable-shared \
            --enable-static

        export PATH="$OLD_PATH"
        end_section

        touch "$BUILDDIR/.configure-libtool-pass1-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libtool-pass1-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libtool-pass1-$ARCH"

        start_section "Make libtool (pass1)"
        OLD_PATH="$PATH"
        if [ "$OSNAME" == "Darwin" ]; then
            export PATH="$PATH:/opt/homebrew/bin"
        fi
        make -j"$PARALLEL" V=1
        export PATH="$OLD_PATH"
        end_section

        start_section "Install libtool (pass1)"
        make install
        end_section

        touch "$BUILDDIR/.build-libtool-pass1-$ARCH.stamp"
    fi

    export LIBTOOL="$PKGBUILDDIR/$PREFIX/$TARGET_TRIPLET/bin/libtool"
    export LIBTOOLIZE="$PKGBUILDDIR/$PREFIX/$TARGET_TRIPLET/bin/libtoolize"

    if [ ! -f "$BUILDDIR/.configure-gcc-pass2-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/gcc-pass2-$ARCH"
        cd "$BUILDDIR/gcc-pass2-$ARCH"

        start_section "Configure GCC (pass2)"
        AR_FOR_TARGET="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-ld -r -o" \
        RANLIB_FOR_TARGET="true" \
        CFLAGS="$ROOT_CPPFLAGS" \
        CXXFLAGS="$ROOT_CPPFLAGS" \
        LDFLAGS="$ROOT_LDFLAGS -s" \
        ../../gcc-strata/configure \
            --build="$BUILD_TRIPLET" \
            --target="$TARGET_TRIPLET" \
            --prefix="$PREFIX" \
            --with-build-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --with-sysroot="$SYSROOT" \
            --with-native-system-header-dir="/usr/include" \
            --with-system-zlib \
            --enable-languages=c,c++ \
            --enable-lto \
            --enable-shared \
            --enable-threads=posix \
            --disable-nls \
            --disable-libsanitizer \
            --disable-werror \
            --disable-multilib \
            --disable-libgomp \
            --enable-libssp \
            --enable-libatomic \
            --enable-libquadmath
        end_section

        touch "$BUILDDIR/.configure-gcc-pass2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-gcc-pass2-$ARCH.stamp" ]; then
        cd "$BUILDDIR/gcc-pass2-$ARCH"

        start_section "Make GCC (pass2)"
        make -j"$PARALLEL" all-gcc 
        end_section

        start_section "Make GCC (pass2) - libgcc"
        make -j"$PARALLEL" all-target-libgcc
        end_section

        start_section "Install GCC (pass2)"
        make install-gcc DESTDIR="$PKGBUILDDIR"
        end_section

        start_section "Install GCC (pass2) - libgcc"
        make install-target-libgcc DESTDIR="$PKGBUILDDIR"
        end_section

        start_section "Make GCC (pass2) - libstdc++"
        make -j"$PARALLEL" all-target-libstdc++-v3 \
            LDFLAGS_FOR_TARGET="-L$PKGBUILDDIR/$PREFIX/$TARGET_TRIPLET/lib"
        end_section

        start_section "Install GCC (pass2) - libstdc++"
        make install-target-libstdc++-v3 DESTDIR="$PKGBUILDDIR"
        end_section
        
        GCC_BUILTIN_INCLUDE_PATH=$("$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-gcc" -print-file-name=include)
        cp "../../gcc-strata/gcc/ginclude/stdint-gcc.h" "$GCC_BUILTIN_INCLUDE_PATH/stdint-gcc.h"

        touch "$BUILDDIR/.build-gcc-pass2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.cleanup-pass1-$ARCH.stamp" ]; then
        cd "$PKGBUILDDIR"

        find "./$SYSROOT/usr/lib/" -name "*.a" -delete
        find "./$SYSROOT/usr/lib/" -name "*.la" -delete
        find "./$SYSROOT/usr/lib/" -name "*.so*" -delete

        touch "$BUILDDIR/.cleanup-pass1-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-musl-pass2-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/musl-pass2-$ARCH"
        cd "$BUILDDIR/musl-pass2-$ARCH"

        start_section "Configure musl libc (pass2)"
        CROSS_COMPILE="$TARGET_TRIPLET-" \
        ../../musl-strata/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$SYSROOT" \
            --target="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --disable-gcc-wrapper
        end_section

        touch "$BUILDDIR/.configure-musl-pass2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-musl-pass2-$ARCH.stamp" ]; then
        cd "$BUILDDIR/musl-pass2-$ARCH"

        start_section "Install musl libc (pass2) - headers"
        make install-headers DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        start_section "Make musl libc (pass2)"
        make -j"$PARALLEL"
        end_section

        start_section "Install musl libc (pass2)"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-musl-pass2-$ARCH.stamp"
    fi

    export PATH="$PKGBUILDDIR/$PREFIX/$TARGET_TRIPLET/bin:$ROOT_PATH"
    export PKG_CONFIG_LIBDIR="$PKGBUILDDIR/$SYSROOT/usr/lib/pkgconfig:$PKGBUILDDIR/$SYSROOT/usr/share/pkgconfig"
    export PKG_CONFIG_SYSROOT_DIR="$PKGBUILDDIR/$SYSROOT"

    export CC="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-gcc"
    export CXX="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-gcc"
    export AR="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-ld -r -o"
    export AS="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-as"
    export OBJCOPY="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-objcopy"
    export LD="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-ld"
    export NM="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-nm"
    export STRIP="$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-strip"
    export RANLIB="true"

    if [ ! -f "$BUILDDIR/.configure-gmp-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/gmp-$ARCH"
        cd "$BUILDDIR/gmp-$ARCH"

        start_section "Configure gmp"
        CFLAGS="-std=gnu11" \
        ../gmp-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-gmp-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-gmp-$ARCH.stamp" ]; then
        cd "$BUILDDIR/gmp-$ARCH"

        start_section "Make gmp"
        make -j"$PARALLEL"
        end_section

        start_section "Install gmp"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-gmp-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-mpfr-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/mpfr-$ARCH"
        cd "$BUILDDIR/mpfr-$ARCH"

        start_section "Configure mpfr"
        ../mpfr-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-mpfr-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-mpfr-$ARCH.stamp" ]; then
        cd "$BUILDDIR/mpfr-$ARCH"

        start_section "Make mpfr"
        make -j"$PARALLEL"
        end_section

        start_section "Install mpfr"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-mpfr-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-mpc-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/mpc-$ARCH"
        cd "$BUILDDIR/mpc-$ARCH"

        start_section "Configure mpc"
        ../mpc-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-mpc-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-mpc-$ARCH.stamp" ]; then
        cd "$BUILDDIR/mpc-$ARCH"

        start_section "Make mpc"
        make -j"$PARALLEL"
        end_section

        start_section "Install mpc"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-mpc-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-nettle-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/nettle-$ARCH"
        cd "$BUILDDIR/nettle-$ARCH"

        start_section "Configure Nettle"
        ../nettle-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --disable-openssl \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-nettle-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-nettle-$ARCH.stamp" ]; then
        cd "$BUILDDIR/nettle-$ARCH"

        start_section "Make Nettle"
        make -j"$PARALLEL" AUTOHEADER="$AUTOHEADER_HOST"
        end_section

        start_section "Install Nettle"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT" AUTOHEADER="$AUTOHEADER_HOST"
        end_section

        touch "$BUILDDIR/.build-nettle-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libsodium-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libsodium-$ARCH"
        cd "$BUILDDIR/libsodium-$ARCH"

        start_section "Configure libsodium"
        ../libsodium-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-libsodium-$ARCH.stamp"
    fi
    
    if [ ! -f "$BUILDDIR/.build-libsodium-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libsodium-$ARCH"

        start_section "Make libsodium"
        make -j"$PARALLEL" V=1
        end_section

        start_section "Install libsodium"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-libsodium-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libffi-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libffi-$ARCH"
        cd "$BUILDDIR/libffi-$ARCH"

        start_section "Configure libffi"
        ../libffi-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-libffi-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libffi-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libffi-$ARCH"

        start_section "Make libffi"
        make -j"$PARALLEL"
        end_section

        start_section "Install libffi"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-libffi-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libuv-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libuv-$ARCH"
        cd "$BUILDDIR/libuv-$ARCH"

        start_section "Configure libuv"
        CPPFLAGS="-D_GNU_SOURCE" \
        ../libuv-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-libuv-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libuv-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libuv-$ARCH"

        start_section "Make libuv"
        make -j"$PARALLEL"
        end_section

        start_section "Install libuv"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-libuv-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libxml2-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libxml2-$ARCH"
        cd "$BUILDDIR/libxml2-$ARCH"

        start_section "Configure libxml2"
        ../libxml2-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-libxml2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libxml2-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libxml2-$ARCH"

        start_section "Make libxml2"
        make -j"$PARALLEL"
        end_section

        start_section "Install libxml2"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-libxml2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libxslt-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libxslt-$ARCH"
        cd "$BUILDDIR/libxslt-$ARCH"

        start_section "Configure libxslt"
        CPPFLAGS="-I$PKGBUILDDIR/$SYSROOT/usr/include/libxml2" \
        ../libxslt-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static \
            --without-python \
            --with-libxml-prefix="$PKGBUILDDIR/$SYSROOT/usr"
        end_section

        touch "$BUILDDIR/.configure-libxslt-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libxslt-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libxslt-$ARCH"

        start_section "Make libxslt"
        make -j"$PARALLEL"
        end_section

        start_section "Install libxslt"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-libxslt-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libexpat-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libexpat-$ARCH"
        cd "$BUILDDIR/libexpat-$ARCH"

        start_section "Configure libexpat"
        ../libexpat-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-libexpat-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libexpat-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libexpat-$ARCH"

        start_section "Make libexpat"
        make -j"$PARALLEL"
        end_section

        start_section "Install libexpat"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-libexpat-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-yyjson-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/yyjson-$ARCH"
        cd "$BUILDDIR/yyjson-$ARCH"

        start_section "Configure yyjson"
        "$CMAKE" -S../yyjson-src -B. \
            -DCMAKE_TOOLCHAIN_FILE="$ROOT/cmake/$TARGET_TRIPLET.cmake" \
            -DCMAKE_FIND_ROOT_PATH="$PKGBUILDDIR/$PREFIX" \
            -DCMAKE_INSTALL_PREFIX="/usr" \
            -DCMAKE_SYSROOT="$PKGBUILDDIR/$SYSROOT" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=OFF \
            -DYYJSON_BUILD_TESTS=OFF
        end_section

        touch "$BUILDDIR/.configure-yyjson-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-yyjson-$ARCH.stamp" ]; then
        cd "$BUILDDIR/yyjson-$ARCH"

        start_section "Make yyjson"
        "$CMAKE" --build . --parallel="$PARALLEL"
        end_section

        start_section "Install yyjson"
        DESTDIR="$PKGBUILDDIR/$SYSROOT" \
        "$CMAKE" --install .
        end_section

        touch "$BUILDDIR/.build-yyjson-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-zlib-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/zlib-$ARCH"
        cd "$BUILDDIR/zlib-$ARCH"

        start_section "Configure zlib"
        rm -rf -- *
        cp -r ../zlib-src/* .
        end_section

        touch "$BUILDDIR/.configure-zlib-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-zlib-$ARCH.stamp" ]; then
        cd "$BUILDDIR/zlib-$ARCH"

        start_section "Make zlib"
        make -f "./folios/Makefile.gcc" -j"$PARALLEL" \
            CROSS_PREFIX="$TARGET_TRIPLET-" \
            CFLAGS="-I."
        end_section

        start_section "Install zlib"
        make -f "./folios/Makefile.gcc" install \
            DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-zlib-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-bzip2-$ARCH.stamp" ]; then
        cd "$BUILDDIR"

        start_section "Configure bzip2"
        mkdir -p "bzip2-$ARCH"
        rm -rf "bzip2-$ARCH"/*
        cp -r bzip2-src/* "bzip2-$ARCH"
        end_section

        touch "$BUILDDIR/.configure-bzip2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-bzip2-$ARCH.stamp" ]; then
        cd "$BUILDDIR/bzip2-$ARCH"

        start_section "Make bzip2"
        make bz2.sl bzip2.app bzip2recover.app -j"$PARALLEL" PREFIX="/usr" \
            CC="$CC" \
            LD="$LD"
        make -f Makefile-bz2_dl -j"$PARALLEL" PREFIX="/usr" \
            CC="$CC" \
            LD="$LD"
        end_section

        start_section "Install bzip2"
        make install PREFIX="$PKGBUILDDIR/$SYSROOT/usr" \
            CC="$CC" \
            LD="$LD"
        cp -f bz2.dl* "$PKGBUILDDIR/$SYSROOT/usr/lib/"
        end_section

        touch "$BUILDDIR/.build-bzip2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-xz-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/xz-$ARCH"
        cd "$BUILDDIR/xz-$ARCH"

        start_section "Configure xz"
        ../xz-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-xz-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-xz-$ARCH.stamp" ]; then
        cd "$BUILDDIR/xz-$ARCH"

        start_section "Make xz"
        make -j"$PARALLEL"
        end_section

        start_section "Install xz"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-xz-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-lz4-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR"
        cd "$BUILDDIR"

        start_section "Configure lz4"
        mkdir -p "lz4-$ARCH"
        rm -rf "lz4-$ARCH"/*
        cp -r lz4-src/* "lz4-$ARCH"
        end_section

        touch "$BUILDDIR/.configure-lz4-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-lz4-$ARCH.stamp" ]; then
        cd "$BUILDDIR/lz4-$ARCH"

        start_section "Make lz4 library"
        make -j"$PARALLEL" \
            PREFIX="/usr" \
            TARGET_OS=foliOS \
            CC="$CC" \
            NM="$NM" \
            LD="$LD" V=1
        end_section

        start_section "Install lz4"
        make install \
            PREFIX="/usr" \
            TARGET_OS=foliOS \
            DESTDIR="$PKGBUILDDIR/$SYSROOT" V=1
        end_section

        touch "$BUILDDIR/.build-lz4-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-zstd-$ARCH.stamp" ]; then
        cd "$BUILDDIR"

        start_section "Configure zstd"
        mkdir -p "zstd-$ARCH"
        rm -rf "zstd-$ARCH"/*
        cp -r zstd-src/* "zstd-$ARCH"
        end_section

        touch "$BUILDDIR/.configure-zstd-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-zstd-$ARCH.stamp" ]; then
        cd "$BUILDDIR/zstd-$ARCH"

        start_section "Make zstd library"
        make -j"$PARALLEL" \
            PREFIX="/usr" \
            OS=foliOS \
            TARGET_SYSTEM=foliOS \
            UNAME_TARGET_SYSTEM=foliOS \
            CC="$CC" \
            NM="$NM" \
            LD="$LD" \
            CPPFLAGS="-fPIC" \
            LDFLAGS="-shared" \
            ZSTD_LIB_ZLIB=1 \
            ZSTD_LIB_LZMA=1 \
            ZSTD_LIB_LZ4=1
        end_section

        start_section "Install zstd"
        make install \
            PREFIX="/usr" \
            OS=foliOS \
            TARGET_SYSTEM=foliOS \
            UNAME_TARGET_SYSTEM=foliOS \
            DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-zstd-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libarchive-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libarchive-$ARCH"
        cd "$BUILDDIR/libarchive-$ARCH"

        start_section "Configure libarchive"
        CPPFLAGS="-DAES_MAX_KEY_SIZE=AES256_KEY_SIZE" \
        ../libarchive-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static \
            --with-zlib \
            --with-bz2lib \
            --with-lzma \
            --with-lz4 \
            --with-zstd \
            --with-nettle \
            --without-openssl \
            --with-expat \
            --without-xml2 \
            LIBS="-lz -lbz2 -llzma -llz4 -lzstd -lnettle -lexpat"
        end_section

        touch "$BUILDDIR/.configure-libarchive-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libarchive-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libarchive-$ARCH"

        start_section "Make libarchive"
        make -j"$PARALLEL"
        end_section

        start_section "Install libarchive"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-libarchive-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libiconv-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libiconv-$ARCH"
        cd "$BUILDDIR/libiconv-$ARCH"

        start_section "Configure libiconv"
        ../libiconv-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static

        cp "$BUILDDIR/libtool-pass1-$ARCH/libtool" "./libtool"
        cp "$BUILDDIR/libtool-pass1-$ARCH/libtool" "./libcharset/libtool"
        end_section

        touch "$BUILDDIR/.configure-libiconv-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libiconv-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libiconv-$ARCH"

        start_section "Make libiconv"
        make -j"$PARALLEL" ARFLAGS="" RANLIB="true"
        end_section

        start_section "Install libiconv"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-libiconv-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-ncurses-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/ncurses-$ARCH"
        cd "$BUILDDIR/ncurses-$ARCH"

        start_section "Configure ncurses"
        # TODO: install database
        ../ncurses-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --with-libtool \
            --with-build-cc=gcc \
            --with-pkg-config-libdir="/usr/lib/pkgconfig" \
            --with-tic-path="$TIC" \
            --without-ada \
            --disable-mixed-case \
            --disable-db-install \
            --enable-shared \
            --enable-static \
            --enable-widec \
            --enable-pc-files \
            --enable-overwrite
        end_section

        touch "$BUILDDIR/.configure-ncurses-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-ncurses-$ARCH.stamp" ]; then
        cd "$BUILDDIR/ncurses-$ARCH"

        start_section "Make ncurses"
        make -j"$PARALLEL" ARFLAGS="" RANLIB="true" LIBTOOL="$LIBTOOL"
        end_section

        start_section "Install ncurses"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        ln -sf libncursesw.dl "$PKGBUILDDIR/$SYSROOT/usr/lib/libncurses.dl"
        end_section
        
        touch "$BUILDDIR/.build-ncurses-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-editline-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/editline-$ARCH"
        cd "$BUILDDIR/editline-$ARCH"

        start_section "Configure editline"
        CFLAGS="-std=gnu11" \
        ../editline-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-editline-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-editline-$ARCH.stamp" ]; then
        cd "$BUILDDIR/editline-$ARCH"

        start_section "Make editline"
        make -j"$PARALLEL"
        end_section

        start_section "Install editline"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section
        
        touch "$BUILDDIR/.build-editline-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-readline-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/readline-$ARCH"
        cd "$BUILDDIR/readline-$ARCH"

        start_section "Configure readline"
        CFLAGS="-std=gnu11" \
        ../readline-src/configure \
            --build="$BUILD_TRIPLET" \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --with-curses \
            --enable-shared \
            --enable-static \
            LIBS="-lncursesw"
        end_section

        touch "$BUILDDIR/.configure-readline-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-readline-$ARCH.stamp" ]; then
        cd "$BUILDDIR/readline-$ARCH"

        start_section "Make readline"
        make -j"$PARALLEL"
        end_section

        start_section "Install readline"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT" V=1
        end_section
        
        touch "$BUILDDIR/.build-readline-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-sqlite3-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/sqlite3-$ARCH"
        cd "$BUILDDIR/sqlite3-$ARCH"

        start_section "Configure sqlite3"
        CFLAGS="-std=gnu11" \
        autosetup_tclsh="$TCLSH" \
        ../sqlite3-src/configure \
            --build="$BUILD_TRIPLET" \
            --host="$TARGET_TRIPLET" \
            --prefix="/usr" \
            --all \
            --soname=sqlite3.dl \
            --with-readline-ldflags="-L$PKGBUILDDIR/$SYSROOT/usr/lib -lreadline -lncursesw" \
            --with-readline-cflags="-I$PKGBUILDDIR/$SYSROOT/usr/include" \
            --dll-basename="sqlite3" \
            AR="$LD -r -o" \
            RANLIB="true" \
            LIBS="-lm -ldl"
        end_section

        touch "$BUILDDIR/.configure-sqlite3-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-sqlite3-$ARCH.stamp" ]; then
        cd "$BUILDDIR/sqlite3-$ARCH"

        start_section "Make sqlite3"
        make -j"$PARALLEL" AR.flags="" T.exe=".app" T.dll=".dl" T.lib=".sl"
        end_section

        start_section "Install sqlite3"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT" \
            AR.flags="" T.exe=".app" T.dll=".dl" T.lib=".sl"
        end_section
        
        touch "$BUILDDIR/.build-sqlite3-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.uninstall-libtool-pass1-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libtool-pass1-$ARCH"

        start_section "Uninstalling libtool (pass1)"
        make uninstall
        end_section

        touch "$BUILDDIR/.uninstall-libtool-pass1-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libtool-pass2-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libtool-pass2-$ARCH"
        cd "$BUILDDIR/libtool-pass2-$ARCH"

        start_section "Configure libtool (pass2)"
        OLD_PATH="$PATH"
        if [ "$OSNAME" == "Darwin" ]; then
            export PATH="$PATH:/opt/homebrew/bin"
        fi
        ../../libtool-strata/configure \
            --build="$BUILD_TRIPLET" \
            --prefix="$PREFIX" \
            --exec-prefix="$PREFIX/$TARGET_TRIPLET" \
            --host="$TARGET_TRIPLET" \
            --enable-ltdl-install \
            --enable-shared \
            --enable-static

        export PATH="$OLD_PATH"
        end_section

        touch "$BUILDDIR/.configure-libtool-pass2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libtool-pass2-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libtool-pass2-$ARCH"

        start_section "Make libtool (pass2)"
        OLD_PATH="$PATH"
        if [ "$OSNAME" == "Darwin" ]; then
            export PATH="$PATH:/opt/homebrew/bin"
        fi
        make -j"$PARALLEL" V=1
        export PATH="$OLD_PATH"
        end_section

        start_section "Install libtool (pass2)"
        make install DESTDIR="$PKGBUILDDIR"
        ln -s "../$TARGET_TRIPLET/bin/libtool" "$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-libtool"
        ln -s "../$TARGET_TRIPLET/bin/libtoolize" "$PKGBUILDDIR/$PREFIX/bin/$TARGET_TRIPLET-libtoolize"
        end_section

        touch "$BUILDDIR/.build-libtool-pass2-$ARCH.stamp"
    fi

    unset PATH
    unset PKG_CONFIG_PATH
    unset PKG_CONFIG_LIBDIR
    unset PKG_CONFIG_SYSROOT_DIR
    unset LIBTOOL
    unset LIBTOOLIZE
    unset CC
    unset CXX
    unset AR
    unset AS
    unset OBJCOPY
    unset LD
    unset NM
    unset STRIP
    unset RANLIB
done

export PATH="$ROOT_PATH"

if [ ! -f "$BUILDDIR/.uninstall-libtool.stamp" ]; then
    cd "$BUILDDIR/libtool"

    start_section "Uninstalling libtool"
    make uninstall
    end_section

    touch "$BUILDDIR/.uninstall-libtool.stamp"
fi


if [ ! -f "$BUILDDIR/.cleanup.stamp" ]; then
    cd "$PKGBUILDDIR/$PREFIX"

    start_section "Cleanup files & build paths"
    find . -name "*.la" -delete
    if [ "$SED_TYPE" == "bsd" ]; then
        LC_ALL=C \
        find . -type f \( -name "*.pc" -o -name "libtool" -o -name "libtoolize" -o -name "*-config" -o -name "*.h" \) \
            -exec sed -i '' "s|$PKGBUILDDIR||g" {} +
    else
        find . -type f \( -name "*.pc" -o -name "libtool" -o -name "libtoolize" -o -name "*-config" -o -name "*.h" \) \
            -exec sed -i "s|$PKGBUILDDIR||g" {} +
    fi
    end_section

    touch "$BUILDDIR/.cleanup.stamp"
fi


if [ ! -f "$BUILDDIR/.archive.stamp" ]; then
    cd "$PKGBUILDDIR/$PREFIX"

    start_section "Make archive"
    tar -czvf "$BUILDDIR/$ARCHIVE_NAME" .
    end_section

    touch "$BUILDDIR/.archive.stamp"
fi
