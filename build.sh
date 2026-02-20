#!/bin/bash

set -xeu

# Common Variables
OSNAME=$(uname -s)
ROOT="$PWD"


# OS-Dependent Tools
if [ "$OSNAME" == "Darwin" ]; then
    GETOPT="/opt/homebrew/opt/gnu-getopt/bin/getopt"
    TCLSH="/opt/homebrew/opt/tcl-tk/bin/tclsh"
    SED_TYPE="bsd"
else
    GETOPT="getopt"
    TCLSH="tclsh"
    SED_TYPE="gnu"
fi
CMAKE="$(which cmake)"


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
source builtin_libraries.cfg


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

export PATH="$PREFIX/bin:$PKGBUILDDIR/$PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
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

    curl --retry 5 --retry-delay 2 -ZL -C - \
        -o "gmp-$GMP_VERSION.tar.xz" "$GMP_URL" \
        -o "mpfr-$MPFR_VERSION.tar.xz" "$MPFR_URL" \
        -o "mpc-$MPC_VERSION.tar.gz" "$MPC_URL" \
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

    # gmp
    rm -rf gmp-src
    tar -xf "gmp-$GMP_VERSION.tar.xz"
    mv "gmp-$GMP_VERSION" gmp-src
    cp -f ../gcc-strata/config.sub gmp-src  # config.sub patch

    # mpfr
    rm -rf mpfr-src
    tar -xf "mpfr-$MPFR_VERSION.tar.xz"
    mv "mpfr-$MPFR_VERSION" mpfr-src
    cp -f ../gcc-strata/config.sub mpfr-src  # config.sub patch

    # mpc
    rm -rf mpc-src
    tar -xf "mpc-$MPC_VERSION.tar.gz"
    mv "mpc-$MPC_VERSION" mpc-src
    cp -f ../gcc-strata/config.sub mpc-src/build-aux  # config.sub patch

    # nettle
    rm -rf nettle-src
    tar -xf "nettle-$NETTLE_VERSION.tar.gz"
    mv "nettle-$NETTLE_VERSION" nettle-src
    cp -f ../gcc-strata/config.sub nettle-src  # config.sub patch

    # libsodium
    rm -rf libsodium-src
    tar -xf "libsodium-$LIBSODIUM_VERSION.tar.gz"
    mv "libsodium-$LIBSODIUM_VERSION" libsodium-src
    cp -f ../gcc-strata/config.sub libsodium-src/build-aux  # config.sub patch

    # libffi
    rm -rf libffi-src
    tar -xf "libffi-$LIBFFI_VERSION.tar.gz"
    mv "libffi-$LIBFFI_VERSION" libffi-src
    cp -f ../gcc-strata/config.sub libffi-src  # config.sub patch

    # libuv
    rm -rf libuv-src
    tar -xf "libuv-v$LIBUV_VERSION.tar.gz"
    mv "libuv-v$LIBUV_VERSION" libuv-src

    # libuv (autogen)
    cd libuv-src

    OLD_PATH="$PATH"
    if [ "$OSNAME" == "Darwin" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
    fi
    sh autogen.sh
    export PATH="$OLD_PATH"

    cd ..
    cp -f ../gcc-strata/config.sub libuv-src  # config.sub patch

    # libxml2
    rm -rf libxml2-src
    tar -xf "libxml2-$LIBXML2_VERSION.tar.xz"
    mv "libxml2-$LIBXML2_VERSION" libxml2-src
    cp -f ../gcc-strata/config.sub libxml2-src  # config.sub patch

    # libxslt
    rm -rf libxslt-src
    tar -xf "libxslt-$LIBXSLT_VERSION.tar.xz"
    mv "libxslt-$LIBXSLT_VERSION" libxslt-src
    cp -f ../gcc-strata/config.sub libxslt-src  # config.sub patch

    # libexpat
    rm -rf libexpat-src
    tar -xf "expat-$LIBEXPAT_VERSION.tar.xz"
    mv "expat-$LIBEXPAT_VERSION" libexpat-src
    cp -f ../gcc-strata/config.sub libexpat-src/conftools  # config.sub patch

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
    cp -f ../gcc-strata/config.sub xz-src/build-aux  # config.sub patch

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
    cp -f ../gcc-strata/config.sub libarchive-src/build/autoconf  # config.sub patch
    if [ "$SED_TYPE" == "bsd" ]; then
        sed -i '' \
            's/hmac_sha1_digest(ctx, (unsigned)\*out_len, out)/hmac_sha1_digest(ctx, out)/g' \
            "libarchive-src/libarchive/archive_hmac.c"
    else
        sed -i \
            's/hmac_sha1_digest(ctx, (unsigned)\*out_len, out)/hmac_sha1_digest(ctx, out)/g' \
            "libarchive-src/libarchive/archive_hmac.c"
    fi

    # libiconv
    rm -rf libiconv-src
    tar -xf "libiconv-$LIBICONV_VERSION.tar.gz"
    mv "libiconv-$LIBICONV_VERSION" libiconv-src
    cp -f ../gcc-strata/config.sub libiconv-src/build-aux  # config.sub patch
    cp -f ../gcc-strata/config.sub libiconv-src/libcharset/build-aux  # config.sub patch

    # ncurses
    rm -rf ncurses-src
    tar -xf "ncurses-$NCURSES_VERSION.tar.gz"
    mv "ncurses-$NCURSES_VERSION" ncurses-src
    cp -f ../gcc-strata/config.sub ncurses-src  # config.sub patch

    # editline
    rm -rf editline-src
    tar -xf "editline-$EDITLINE_VERSION.tar.gz"
    mv "editline-$EDITLINE_VERSION" editline-src
    cp -f ../gcc-strata/config.sub editline-src/aux  # config.sub patch

    # readline
    rm -rf readline-src
    tar -xf "readline-$READLINE_VERSION.tar.gz"
    mv "readline-$READLINE_VERSION" readline-src
    cp -f ../gcc-strata/config.sub readline-src/support  # config.sub patch

    # sqlite3
    rm -rf sqlite3-src
    tar -xf "sqlite-autoconf-$SQLITE3_VERSION.tar.gz"
    DIRNAME=$(tar -tf "sqlite-autoconf-$SQLITE3_VERSION.tar.gz" | head -1 | cut -f1 -d"/")
    mv "$DIRNAME" sqlite3-src
    cp -f ../gcc-strata/config.sub sqlite3-src/autosetup/autosetup-config.sub  # config.sub patch

    touch "$BUILDDIR/.download-sources.stamp"
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

HOST_TIC="$BUILDDIR/ncurses/progs/tic"

ROOT_CPPFLAGS="$CPPFLAGS"
ROOT_LDFLAGS="$LDFLAGS"
for ARCH in "${ARCHS[@]}"; do
    # Per-Target Build Settings
    TARGET="$ARCH-strata-folios"
    SYSROOT="$PREFIX/$TARGET/sysroot"

    mkdir -p "$PKGBUILDDIR/$SYSROOT"

    export CPPFLAGS="-I$PKGBUILDDIR/$SYSROOT/include $ROOT_CPPFLAGS"
    export LDFLAGS="-L$PKGBUILDDIR/$SYSROOT/lib $ROOT_LDFLAGS"
    export PKG_CONFIG_PATH=""
    export PKG_CONFIG_LIBDIR="$PKGBUILDDIR/$SYSROOT/usr/lib/pkgconfig:$PKGBUILDDIR/$SYSROOT/usr/share/pkgconfig"
    export PKG_CONFIG_SYSROOT_DIR="$PKGBUILDDIR/$SYSROOT"
    export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
    export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1

    # Per-Target Builds
    if [ ! -f "$BUILDDIR/.configure-binutils-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/binutils-$ARCH"
        cd "$BUILDDIR/binutils-$ARCH"

        start_section "Configure binutils"
        LDFLAGS="$LDFLAGS -s" \
        ../../binutils-strata/configure \
            --target="$TARGET" \
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
        LDFLAGS="$LDFLAGS -s" \
        ../../gcc-strata/configure \
            --target="$TARGET" \
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
        CROSS_COMPILE="$TARGET-" \
        ../../musl-strata/configure \
            --target="$TARGET" \
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

        echo "GROUP ( libc.a )" > "$PKGBUILDDIR/$SYSROOT/usr/lib/libc.so"

        touch "$BUILDDIR/.build-musl-pass1-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-gcc-pass2-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/gcc-pass2-$ARCH"
        cd "$BUILDDIR/gcc-pass2-$ARCH"

        start_section "Configure GCC (pass2)"
        LDFLAGS="$LDFLAGS -s" \
        ../../gcc-strata/configure \
            --target="$TARGET" \
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
        make -j"$PARALLEL" all-target-libstdc++-v3
        end_section

        start_section "Install GCC (pass2) - libstdc++"
        make install-target-libstdc++-v3 DESTDIR="$PKGBUILDDIR"
        end_section
        
        GCC_BUILTIN_INCLUDE_PATH=$("$PKGBUILDDIR/$PREFIX/bin/$TARGET-gcc" -print-file-name=include)
        cp "../../gcc-strata/gcc/ginclude/stdint-gcc.h" "$GCC_BUILTIN_INCLUDE_PATH/stdint-gcc.h"

        touch "$BUILDDIR/.build-gcc-pass2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-musl-pass2-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/musl-pass2-$ARCH"
        cd "$BUILDDIR/musl-pass2-$ARCH"

        start_section "Configure musl libc (pass2)"
        CROSS_COMPILE="$TARGET-" \
        ../../musl-strata/configure \
            --with-sysroot="$SYSROOT" \
            --target="$TARGET" \
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

    if [ ! -f "$BUILDDIR/.configure-gmp-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/gmp-$ARCH"
        cd "$BUILDDIR/gmp-$ARCH"

        start_section "Configure gmp"
        CC="$PKGBUILDDIR/$PREFIX/bin/$TARGET-gcc" \
        AR="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ar" \
        NM="$PKGBUILDDIR/$PREFIX/bin/$TARGET-nm" \
        AS="$PKGBUILDDIR/$PREFIX/bin/$TARGET-as" \
        LD="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ld" \
        STRIP="$PKGBUILDDIR/$PREFIX/bin/$TARGET-strip" \
        RANLIB="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ranlib" \
        CFLAGS="-std=gnu11" \
        ../gmp-src/configure \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
        make -j"$PARALLEL"
        end_section

        start_section "Install Nettle"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-nettle-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libsodium-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libsodium-$ARCH"
        cd "$BUILDDIR/libsodium-$ARCH"

        start_section "Configure libsodium"
        ../libsodium-src/configure \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-libsodium-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libsodium-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libsodium-$ARCH"

        start_section "Make libsodium"
        make -j"$PARALLEL"
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
        CPPFLAGS="$CPPFLAGS -I$PKGBUILDDIR/$SYSROOT/usr/include/libxml2" \
        ../libxslt-src/configure \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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

    if [ ! -f "$BUILDDIR/.configure-yyjson-$ARCH-shared.stamp" ]; then
        mkdir -p "$BUILDDIR/yyjson-$ARCH-shared"
        cd "$BUILDDIR/yyjson-$ARCH-shared"

        start_section "Configure yyjson"
        "$CMAKE" -S../yyjson-src -B. \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
            -DCMAKE_C_COMPILER="$PKGBUILDDIR/$PREFIX/bin/$TARGET-gcc" \
            -DCMAKE_INSTALL_PREFIX="/usr" \
            -DCMAKE_FIND_ROOT_PATH="$PKGBUILDDIR/$SYSROOT" \
            -DBUILD_SHARED_LIBS=ON \
            -DYYJSON_BUILD_TESTS=OFF
        end_section

        touch "$BUILDDIR/.configure-yyjson-$ARCH-shared.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-yyjson-$ARCH-shared.stamp" ]; then
        cd "$BUILDDIR/yyjson-$ARCH-shared"

        start_section "Make yyjson"
        make -j"$PARALLEL"
        end_section

        start_section "Install yyjson"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-yyjson-$ARCH-shared.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-yyjson-$ARCH-static.stamp" ]; then
        mkdir -p "$BUILDDIR/yyjson-$ARCH-static"
        cd "$BUILDDIR/yyjson-$ARCH-static"

        start_section "Configure yyjson"
        "$CMAKE" -S../yyjson-src -B. \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
            -DCMAKE_C_COMPILER="$PKGBUILDDIR/$PREFIX/bin/$TARGET-gcc" \
            -DCMAKE_INSTALL_PREFIX="/usr" \
            -DCMAKE_FIND_ROOT_PATH="$PKGBUILDDIR/$SYSROOT" \
            -DBUILD_SHARED_LIBS=OFF \
            -DYYJSON_BUILD_TESTS=OFF
        end_section

        touch "$BUILDDIR/.configure-yyjson-$ARCH-static.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-yyjson-$ARCH-static.stamp" ]; then
        cd "$BUILDDIR/yyjson-$ARCH-static"

        start_section "Make yyjson"
        make -j"$PARALLEL"
        end_section

        start_section "Install yyjson"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-yyjson-$ARCH-static.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-zlib-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/zlib-$ARCH"
        cd "$BUILDDIR/zlib-$ARCH"

        start_section "Configure zlib"
        CHOST="$TARGET" \
        ../zlib-src/configure \
            --prefix="/usr"
        end_section

        touch "$BUILDDIR/.configure-zlib-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-zlib-$ARCH.stamp" ]; then
        cd "$BUILDDIR/zlib-$ARCH"

        start_section "Make zlib"
        make -j"$PARALLEL"
        end_section

        start_section "Install zlib"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
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
        make libbz2.a bzip2 bzip2recover -j"$PARALLEL" \
            PREFIX="/usr" \
            CC="$PKGBUILDDIR/$PREFIX/bin/$TARGET-gcc" \
            AR="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ar" \
            RANLIB="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ranlib"
        end_section

        start_section "Install bzip2"
        make install PREFIX="$PKGBUILDDIR/$SYSROOT/usr"
        end_section

        touch "$BUILDDIR/.build-bzip2-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-xz-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/xz-$ARCH"
        cd "$BUILDDIR/xz-$ARCH"

        start_section "Configure xz"
        ../xz-src/configure \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            TARGET_OS=Linux \
            CC="$PKGBUILDDIR/$PREFIX/bin/$TARGET-gcc" \
            AR="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ar" \
            NM="$PKGBUILDDIR/$PREFIX/bin/$TARGET-nm" \
            LD="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ld" \
            RANLIB="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ranlib"
        end_section

        start_section "Install lz4"
        make install \
            PREFIX="/usr" \
            TARGET_OS=Linux \
            DESTDIR="$PKGBUILDDIR/$SYSROOT"
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
            TARGET_SYSTEM=Linux \
            UNAME_TARGET_SYSTEM=Linux \
            CC="$PKGBUILDDIR/$PREFIX/bin/$TARGET-gcc" \
            AR="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ar" \
            NM="$PKGBUILDDIR/$PREFIX/bin/$TARGET-nm" \
            LD="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ld" \
            RANLIB="$PKGBUILDDIR/$PREFIX/bin/$TARGET-ranlib" \
            CPPFLAGS="$CPPFLAGS -fPIC" \
            LDFLAGS="$LDFLAGS -shared" \
            ZSTD_LIB_ZLIB=1 \
            ZSTD_LIB_LZMA=1 \
            ZSTD_LIB_LZ4=1
        end_section

        start_section "Install zstd"
        make install \
            PREFIX="/usr" \
            TARGET_SYSTEM=Linux \
            UNAME_TARGET_SYSTEM=Linux \
            DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section

        touch "$BUILDDIR/.build-zstd-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-libarchive-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/libarchive-$ARCH"
        cd "$BUILDDIR/libarchive-$ARCH"

        start_section "Configure libarchive"
        CPPFLAGS="$CPPFLAGS -DAES_MAX_KEY_SIZE=AES256_KEY_SIZE" \
        ../libarchive-src/configure \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
            --prefix="/usr" \
            --enable-shared \
            --enable-static
        end_section

        touch "$BUILDDIR/.configure-libiconv-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-libiconv-$ARCH.stamp" ]; then
        cd "$BUILDDIR/libiconv-$ARCH"

        start_section "Make libiconv"
        make -j"$PARALLEL"
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
            --prefix="/usr" \
            --with-build-cc=gcc \
            --with-pkg-config-libdir="/usr/lib/pkgconfig" \
            --with-tic-path="$HOST_TIC" \
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
        make -j"$PARALLEL"
        end_section

        start_section "Install ncurses"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        ln -sf libncursesw.so "$PKGBUILDDIR/$SYSROOT/usr/lib/libncurses.so"
        end_section
        
        touch "$BUILDDIR/.build-ncurses-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.configure-editline-$ARCH.stamp" ]; then
        mkdir -p "$BUILDDIR/editline-$ARCH"
        cd "$BUILDDIR/editline-$ARCH"

        start_section "Configure editline"
        CFLAGS="-std=gnu11" \
        ../editline-src/configure \
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
            --with-sysroot="$PKGBUILDDIR/$SYSROOT" \
            --host="$TARGET" \
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
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
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
            --host="$TARGET" \
            --prefix="/usr" \
            --all \
            --soname=none \
            --with-readline-ldflags="-L$PKGBUILDDIR/$SYSROOT/usr/lib -lreadline -lncursesw" \
            --with-readline-cflags="-I$PKGBUILDDIR/$SYSROOT/usr/include" \
            LIBS="-lm -ldl"
        end_section

        touch "$BUILDDIR/.configure-sqlite3-$ARCH.stamp"
    fi

    if [ ! -f "$BUILDDIR/.build-sqlite3-$ARCH.stamp" ]; then
        cd "$BUILDDIR/sqlite3-$ARCH"

        start_section "Make sqlite3"
        make -j"$PARALLEL"
        end_section

        start_section "Install sqlite3"
        make install DESTDIR="$PKGBUILDDIR/$SYSROOT"
        end_section
        
        touch "$BUILDDIR/.build-sqlite3-$ARCH.stamp"
    fi
done

if [ ! -f "$BUILDDIR/.archive.stamp" ]; then
    cd "$PKGBUILDDIR/$PREFIX"

    start_section "Make archive"
    tar -czvf "$BUILDDIR/$ARCHIVE_NAME" .
    end_section

    touch "$BUILDDIR/.archive.stamp"
fi
