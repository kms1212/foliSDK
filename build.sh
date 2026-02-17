#!/bin/bash

set -eu

OSNAME=$(uname -s)
ROOT="$PWD"

ARCHIVE_NAME="folisdk-0.0.1.tar.gz"
ARCH=x86_64
ZLIB_VER="1.3.1"
PREFIX=
SYSROOT=
PARALLEL=
BUILDDIR=$PWD/build


if [ "$OSNAME" == "Darwin" ]; then
    GETOPT="/opt/homebrew/opt/gnu-getopt/bin/getopt"
else
    GETOPT="getopt"
fi

GETOPT_OUTPUT=$("$GETOPT" -o "a:b:hj:p:s:z:" --long "arch:,build-dir:,help,jobs:,prefix:,sysroot:,zlib-version:" --name "$(basename "$0")" -- "$@")

if [ $? != 0 ]; then
    exit 1
fi

eval set -- "$GETOPT_OUTPUT"

while :; do
    case "$1" in
        -h | --help)
            echo "Usage: $(basename "$0") [options]"
            echo "Options:"
            echo "  -a, --arch <arch>      Set the target architecture"
            echo "  -b, --build-dir <path> Set the build directory"
            echo "  -j, --jobs <number>    Set the number of jobs"
            echo "  -p, --prefix <path>    Set the prefix directory"
            echo "  -s, --sysroot <path>   Set the sysroot directory"
            echo "  -z, --zlib-version <version>  Set the zlib version"
            exit 0
            ;;
        -b | --build-dir)
            BUILDDIR="$2"
            shift 2
            ;;
        -p | --prefix)
            PREFIX="$2"
            shift 2
            ;;
        -a | --arch)
            ARCH="$2"
            shift 2
            ;;
        -z | --zlib-version)
            ZLIB_VER="$2"
            shift 2
            ;;
        -s | --sysroot)
            SYSROOT="$2"
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

TARGET="$ARCH-strata-folios"

if [ -z "$PREFIX" ]; then
    if [ "$OSNAME" == "Darwin" ]; then
        PREFIX="/opt/homebrew/opt/folisdk"
    else
        PREFIX="/opt/folisdk"
    fi
fi

if [ -z "$SYSROOT" ]; then
    SYSROOT="$PREFIX/$TARGET/sysroot"
fi

if [ -z "$PARALLEL" ]; then
    if [ "$OSNAME" == "Darwin" ]; then
        PARALLEL=$(($(sysctl -n hw.ncpu) - 1))
    else
        PARALLEL=$(($(nproc) - 1))
    fi
fi

if [ "$OSNAME" == "Darwin" ]; then
    SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
    export SDKROOT
fi

PKGBUILDDIR="$BUILDDIR/pkgroot"

export PATH="$PREFIX/bin:$PKGBUILDDIR/$PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
unset LD_LIBRARY_PATH
unset DYLD_LIBRARY_PATH
unset C_INCLUDE_PATH
unset CPLUS_INCLUDE_PATH
unset LIBRARY_PATH

if [ "$OSNAME" == "Darwin" ]; then
    export MAKEINFO=/opt/homebrew/bin/makeinfo
fi

export CPPFLAGS="-I$PKGBUILDDIR/$PREFIX/include"
export LDFLAGS="-L$PKGBUILDDIR/$PREFIX/lib"

mkdir -p "$PKGBUILDDIR"
mkdir -p "$PKGBUILDDIR/$SYSROOT"

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

configure_zlib() {
    cd "$BUILDDIR"

    if [ ! -f "zlib-$ZLIB_VER.tar.gz" ]; then
        curl -O "https://zlib.net/fossils/zlib-$ZLIB_VER.tar.gz"
    fi

    rm -rf zlib
    tar -xzf "zlib-$ZLIB_VER.tar.gz"
    mv "zlib-$ZLIB_VER" zlib

    cd zlib

    start_section "Configure zlib"
    ./configure --prefix="$PREFIX" --static
    end_section

    cd ../..
}

make_zlib() {
    cd "$BUILDDIR/zlib"

    start_section "Make zlib"
    make -j"$PARALLEL"
    end_section

    start_section "Install zlib"
    make install DESTDIR="$PKGBUILDDIR"
    end_section

    cd ../..
}

configure_binutils() {
    cd "$BUILDDIR"

    mkdir -p binutils
    cd binutils

    start_section "Configure binutils"
    LDFLAGS="-s" \
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

    cd ../..
}

make_binutils() {
    cd "$BUILDDIR/binutils"

    start_section "Make binutils"
    make -j"$PARALLEL"
    end_section

    start_section "Install binutils"
    make install DESTDIR="$PKGBUILDDIR"
    end_section

    cd ../..
}

configure_gcc_pass1() {
    cd "$BUILDDIR"

    mkdir -p gcc-pass1
    cd gcc-pass1

    start_section "Configure GCC (pass1)"
    LDFLAGS="-s" \
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

    cd ../..
}

make_gcc_pass1() {
    cd "$BUILDDIR/gcc-pass1"

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

    cd ../..
}

configure_musl_pass1() {
    cd "$BUILDDIR"

    mkdir -p musl-pass1
    cd musl-pass1

    start_section "Configure musl libc (pass1)"
    CROSS_COMPILE="$TARGET-" \
    ../../musl-strata/configure \
        --target="$TARGET" \
        --prefix="$SYSROOT/usr" \
        --disable-shared \
        --disable-gcc-wrapper
    end_section

    cd ../..
}

make_musl_pass1() {
    cd "$BUILDDIR/musl-pass1"

    start_section "Install musl libc (pass1) - headers"
    make install-headers
    end_section

    start_section "Make musl libc (pass1)"
    make -j"$PARALLEL"
    end_section

    start_section "Install musl libc (pass1)"
    make install DESTDIR="$PKGBUILDDIR"
    end_section

    echo "GROUP ( libc.a )" > "$PKGBUILDDIR/$SYSROOT/usr/lib/libc.so"

    cd ../..
}

configure_gcc_pass2() {
    cd "$BUILDDIR"

    mkdir -p gcc-pass2
    cd gcc-pass2

    start_section "Configure GCC (pass2)"
    LDFLAGS="-s" \
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
    
    cd ../..
}

make_gcc_pass2() {
    cd "$BUILDDIR/gcc-pass2"

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

    cd ../..
}


configure_musl_pass2() {
    cd "$BUILDDIR"

    mkdir -p musl-pass2
    cd musl-pass2

    start_section "Configure musl libc (pass2)"
    CROSS_COMPILE="$TARGET-" \
    ../../musl-strata/configure \
        --target="$TARGET" \
        --prefix="$SYSROOT/usr" \
        --disable-gcc-wrapper
    end_section

    cd ../..
}

make_musl_pass2() {
    cd "$BUILDDIR/musl-pass2"

    start_section "Install musl libc (pass2) - headers"
    make install-headers
    end_section

    start_section "Make musl libc (pass2)"
    make -j"$PARALLEL"
    end_section

    start_section "Install musl libc (pass2)"
    make install DESTDIR="$PKGBUILDDIR"
    end_section

    rm -f "$PKGBUILDDIR/lib/ld-musl-$ARCH.so.1"
    rmdir "$PKGBUILDDIR/lib" || true

    ln -sf "../$TARGET/sysroot/usr/lib/libc.so" "$PKGBUILDDIR/$PREFIX/lib/ld-musl-$ARCH.so.1"

    cd ../..
}

make_archive() {
    cd "$PKGBUILDDIR/$PREFIX"

    start_section "Make archive"
    tar -czvf "$BUILDDIR/$ARCHIVE_NAME" .
    end_section

    cd "$ROOT"
}

if [ ! -f "$BUILDDIR/.configure-zlib.stamp" ] || [ "${1:-}" == "cfg-zlib" ]; then
    if [ "${1:-}" == "cfg-zlib" ]; then
        shift
    fi
    configure_zlib
    touch "$BUILDDIR/.configure-zlib.stamp"
fi

if [ ! -f "$BUILDDIR/.zlib.stamp" ] || [ "${1:-}" == "make-zlib" ]; then
    if [ "${1:-}" == "make-zlib" ]; then
        shift
    fi
    make_zlib
    touch "$BUILDDIR/.zlib.stamp"
fi

if [ ! -f "$BUILDDIR/.configure-binutils.stamp" ] || [ "${1:-}" == "cfg-binutils" ]; then
    if [ "${1:-}" == "cfg-binutils" ]; then
        shift
    fi
    configure_binutils
    touch "$BUILDDIR/.configure-binutils.stamp"
fi

if [ ! -f "$BUILDDIR/.binutils.stamp" ] || [ "${1:-}" == "make-binutils" ]; then
    if [ "${1:-}" == "make-binutils" ]; then
        shift
    fi
    make_binutils
    touch "$BUILDDIR/.binutils.stamp"
fi

if [ ! -f "$BUILDDIR/.configure-gcc-pass1.stamp" ] || [ "${1:-}" == "cfg-gcc-pass1" ]; then
    if [ "${1:-}" == "cfg-gcc-pass1" ]; then
        shift
    fi
    configure_gcc_pass1
    touch "$BUILDDIR/.configure-gcc-pass1.stamp"
fi

if [ ! -f "$BUILDDIR/.gcc-pass1.stamp" ] || [ "${1:-}" == "make-gcc-pass1" ]; then
    if [ "${1:-}" == "make-gcc-pass1" ]; then
        shift
    fi
    make_gcc_pass1
    touch "$BUILDDIR/.gcc-pass1.stamp"
fi

if [ ! -f "$BUILDDIR/.configure-musl-pass1.stamp" ] || [ "${1:-}" == "cfg-musl-pass1" ]; then
    if [ "${1:-}" == "cfg-musl-pass1" ]; then
        shift
    fi
    configure_musl_pass1
    touch "$BUILDDIR/.configure-musl-pass1.stamp"
fi

if [ ! -f "$BUILDDIR/.musl-pass1.stamp" ] || [ "${1:-}" == "make-musl-pass1" ]; then
    if [ "${1:-}" == "make-musl-pass1" ]; then
        shift
    fi
    make_musl_pass1
    touch "$BUILDDIR/.musl-pass1.stamp"
fi

if [ ! -f "$BUILDDIR/.configure-gcc-pass2.stamp" ] || [ "${1:-}" == "cfg-gcc-pass2" ]; then
    if [ "${1:-}" == "cfg-gcc-pass2" ]; then
        shift
    fi
    configure_gcc_pass2
    touch "$BUILDDIR/.configure-gcc-pass2.stamp"
fi

if [ ! -f "$BUILDDIR/.gcc-pass2.stamp" ] || [ "${1:-}" == "make-gcc-pass2" ]; then
    if [ "${1:-}" == "make-gcc-pass2" ]; then
        shift
    fi
    make_gcc_pass2
    touch "$BUILDDIR/.gcc-pass2.stamp"
fi

if [ ! -f "$BUILDDIR/.configure-musl-pass2.stamp" ] || [ "${1:-}" == "cfg-musl-pass2" ]; then
    if [ "${1:-}" == "cfg-musl-pass2" ]; then
        shift
    fi
    configure_musl_pass2
    touch "$BUILDDIR/.configure-musl-pass2.stamp"
fi

if [ ! -f "$BUILDDIR/.musl-pass2.stamp" ] || [ "${1:-}" == "make-musl-pass2" ]; then
    if [ "${1:-}" == "make-musl-pass2" ]; then
        shift
    fi
    make_musl_pass2
    touch "$BUILDDIR/.musl-pass2.stamp"
fi

if [ ! -f "$BUILDDIR/.archive.stamp" ] || [ "${1:-}" == "make-archive" ]; then
    if [ "${1:-}" == "make-archive" ]; then
        shift
    fi
    make_archive
    touch "$BUILDDIR/.archive.stamp"
fi
