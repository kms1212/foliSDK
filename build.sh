#!/bin/bash

set -eu

OSNAME=$(uname -s)
ROOT="$PWD"

ARCHIVE_NAME="folisdk-0.0.1.tar.gz"
TARGET=x86_64-strata-folios
ZLIB_VER="1.3.1"
PREFIX=
SYSROOT=
PARALLEL=

GETOPT_OUTPUT=$(getopt -o "hp:t:z:s:j:" --long "help,prefix:,target:,zlib-version:,sysroot:,jobs:" --name "$(basename "$0")" -- "$@")

if [ $? != 0 ]; then
    exit 1
fi

eval set -- "$GETOPT_OUTPUT"

while :; do
    case $1 in
        -h | --help)
            echo "Usage: $(basename "$0") [options]"
            echo "Options:"
            echo "  -p, --prefix <path>    Set the prefix directory (default: $PREFIX)"
            echo "  -t, --target <target>  Set the target architecture (default: $TARGET)"
            echo "  -z, --zlib-version <version>  Set the zlib version (default: $ZLIB_VER)"
            echo "  -s, --sysroot <path>   Set the sysroot directory (default: $SYSROOT)"
            echo "  -j, --jobs <number>    Set the number of jobs (default: $PARALLEL)"
            exit 0
            ;;
        -p | --prefix)
            PREFIX="$2"
            shift 2
            ;;
        -t | --target)
            TARGET="$2"
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

BUILDDIR="$PWD/build/pkgroot"

export PATH="$PREFIX/bin:$BUILDDIR/$PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
unset LD_LIBRARY_PATH
unset DYLD_LIBRARY_PATH
unset C_INCLUDE_PATH
unset CPLUS_INCLUDE_PATH
unset LIBRARY_PATH

if [ "$OSNAME" == "Darwin" ]; then
    export MAKEINFO=/opt/homebrew/bin/makeinfo
fi

export CPPFLAGS="-I$BUILDDIR/$PREFIX/include"
export LDFLAGS="-L$BUILDDIR/$PREFIX/lib"

mkdir -p "$BUILDDIR"
mkdir -p "$BUILDDIR/$SYSROOT"

configure_zlib() {
    cd build

    if [ ! -f "zlib-$ZLIB_VER.tar.gz" ]; then
        curl -O "https://zlib.net/zlib-$ZLIB_VER.tar.gz"
    fi

    rm -rf zlib
    tar -xzf "zlib-$ZLIB_VER.tar.gz"
    mv "zlib-$ZLIB_VER" zlib

    cd zlib

    ./configure --prefix="$PREFIX" --static

    cd ../..
}

make_zlib() {
    cd build/zlib

    make -j"$PARALLEL"
    make install DESTDIR="$BUILDDIR"

    cd ../..
}

configure_binutils() {
    cd build

    mkdir -p binutils
    cd binutils

    ../../binutils-strata/configure \
        --target="$TARGET" \
        --prefix="$PREFIX" \
        --with-build-sysroot="$BUILDDIR/$SYSROOT" \
        --with-sysroot="$SYSROOT" \
        --disable-nls \
        --disable-werror \
        --enable-static \
        --with-system-zlib

    cd ../..
}

make_binutils() {
    cd build/binutils

    make -j"$PARALLEL"
    make install DESTDIR="$BUILDDIR"

    cd ../..
}

configure_gcc_pass1() {
    cd build

    mkdir -p gcc-pass1
    cd gcc-pass1

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

    cd ../..
}

make_gcc_pass1() {
    cd build/gcc-pass1

    make -j"$PARALLEL" all-gcc
    make -j"$PARALLEL" all-target-libgcc
    make install-gcc DESTDIR="$BUILDDIR"
    make install-target-libgcc DESTDIR="$BUILDDIR"

    GCC_BUILTIN_INCLUDE_PATH=$("$BUILDDIR/$PREFIX/bin/$TARGET-gcc" -print-file-name=include)

    cp "../../gcc-strata/gcc/ginclude/stdint-gcc.h" "$GCC_BUILTIN_INCLUDE_PATH/stdint-gcc.h"

    cd ../..
}

configure_musl_pass1() {
    cd build

    mkdir -p musl-pass1
    cd musl-pass1

    CROSS_COMPILE="$TARGET-" \
    ../../musl-strata/configure \
        --target="$TARGET" \
        --prefix="$SYSROOT/usr" \
        --disable-shared \
        --disable-gcc-wrapper

    cd ../..
}

make_musl_pass1() {
    cd build/musl-pass1

    make install-headers

    make -j"$PARALLEL"

    make install DESTDIR="$BUILDDIR"

    ln -s crt1.o "$BUILDDIR/$SYSROOT/usr/lib/crt0.o"

    echo "GROUP ( libc.a )" > "$BUILDDIR/$SYSROOT/usr/lib/libc.so"

    cd ../..
}

configure_gcc_pass2() {
    cd build

    mkdir -p gcc-pass2
    cd gcc-pass2

    ../../gcc-strata/configure \
        --target="$TARGET" \
        --prefix="$PREFIX" \
        --with-build-sysroot="$BUILDDIR/$SYSROOT" \
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
    
    cd ../..
}

make_gcc_pass2() {
    cd build/gcc-pass2

    make -j"$PARALLEL" all-gcc
    make -j"$PARALLEL" all-target-libgcc
    make install-gcc DESTDIR="$BUILDDIR"
    make install-target-libgcc DESTDIR="$BUILDDIR"

    make -j"$PARALLEL" all-target-libstdc++-v3
    make install-target-libstdc++-v3 DESTDIR="$BUILDDIR"
    
    cd ../..
}


configure_musl_pass2() {
    cd build

    mkdir -p musl-pass2
    cd musl-pass2

    CROSS_COMPILE="$TARGET-" \
    ../../musl-strata/configure \
        --target="$TARGET" \
        --prefix="$SYSROOT/usr" \
        --disable-gcc-wrapper

    cd ../..
}

make_musl_pass2() {
    cd build/musl-pass2

    make install-headers

    make -j"$PARALLEL"

    make install DESTDIR="$BUILDDIR"

    rm -f "$BUILDDIR/lib/ld-musl-x86_64.so.1"
    rmdir "$BUILDDIR/lib" || true

    ln -sf "../$TARGET/sysroot/usr/lib/libc.so" "$BUILDDIR/$PREFIX/lib/ld-musl-x86_64.so.1"

    cd ../..
}

make_archive() {
    cd build

    cd "$BUILDDIR/$PREFIX"
    tar -czvf "$ROOT/build/$ARCHIVE_NAME" .

    cd "$ROOT"
}

if [ ! -f "build/.configure-zlib.stamp" ] || [ "${1:-}" == "cfg-zlib" ]; then
    if [ "${1:-}" == "cfg-zlib" ]; then
        shift
    fi
    configure_zlib
    touch "build/.configure-zlib.stamp"
fi

if [ ! -f "build/.zlib.stamp" ] || [ "${1:-}" == "make-zlib" ]; then
    if [ "${1:-}" == "make-zlib" ]; then
        shift
    fi
    make_zlib
    touch "build/.zlib.stamp"
fi

if [ ! -f "build/.configure-binutils.stamp" ] || [ "${1:-}" == "cfg-binutils" ]; then
    if [ "${1:-}" == "cfg-binutils" ]; then
        shift
    fi
    configure_binutils
    touch "build/.configure-binutils.stamp"
fi

if [ ! -f "build/.binutils.stamp" ] || [ "${1:-}" == "make-binutils" ]; then
    if [ "${1:-}" == "make-binutils" ]; then
        shift
    fi
    make_binutils
    touch "build/.binutils.stamp"
fi

if [ ! -f "build/.configure-gcc-pass1.stamp" ] || [ "${1:-}" == "cfg-gcc-pass1" ]; then
    if [ "${1:-}" == "cfg-gcc-pass1" ]; then
        shift
    fi
    configure_gcc_pass1
    touch "build/.configure-gcc-pass1.stamp"
fi

if [ ! -f "build/.gcc-pass1.stamp" ] || [ "${1:-}" == "make-gcc-pass1" ]; then
    if [ "${1:-}" == "make-gcc-pass1" ]; then
        shift
    fi
    make_gcc_pass1
    touch "build/.gcc-pass1.stamp"
fi

if [ ! -f "build/.configure-musl-pass1.stamp" ] || [ "${1:-}" == "cfg-musl-pass1" ]; then
    if [ "${1:-}" == "cfg-musl-pass1" ]; then
        shift
    fi
    configure_musl_pass1
    touch "build/.configure-musl-pass1.stamp"
fi

if [ ! -f "build/.musl-pass1.stamp" ] || [ "${1:-}" == "make-musl-pass1" ]; then
    if [ "${1:-}" == "make-musl-pass1" ]; then
        shift
    fi
    make_musl_pass1
    touch "build/.musl-pass1.stamp"
fi

if [ ! -f "build/.configure-gcc-pass2.stamp" ] || [ "${1:-}" == "cfg-gcc-pass2" ]; then
    if [ "${1:-}" == "cfg-gcc-pass2" ]; then
        shift
    fi
    configure_gcc_pass2
    touch "build/.configure-gcc-pass2.stamp"
fi

if [ ! -f "build/.gcc-pass2.stamp" ] || [ "${1:-}" == "make-gcc-pass2" ]; then
    if [ "${1:-}" == "make-gcc-pass2" ]; then
        shift
    fi
    make_gcc_pass2
    touch "build/.gcc-pass2.stamp"
fi

if [ ! -f "build/.configure-musl-pass2.stamp" ] || [ "${1:-}" == "cfg-musl-pass2" ]; then
    if [ "${1:-}" == "cfg-musl-pass2" ]; then
        shift
    fi
    configure_musl_pass2
    touch "build/.configure-musl-pass2.stamp"
fi

if [ ! -f "build/.musl-pass2.stamp" ] || [ "${1:-}" == "make-musl-pass2" ]; then
    if [ "${1:-}" == "make-musl-pass2" ]; then
        shift
    fi
    make_musl_pass2
    touch "build/.musl-pass2.stamp"
fi

if [ ! -f "build/.archive.stamp" ] || [ "${1:-}" == "make-archive" ]; then
    if [ "${1:-}" == "make-archive" ]; then
        shift
    fi
    make_archive
    touch "build/.archive.stamp"
fi
