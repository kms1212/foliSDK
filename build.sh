#!/bin/bash

set -eu

ZLIB_VER="1.3.1"

PWD=$(pwd)
NPROC=$(sysctl -n hw.ncpu)
PARALLEL=$(($NPROC - 1))

export PREFIX="$PWD/build/pkgroot"
export TARGET=x86_64-strata-folios
export SYSROOT="$PREFIX/$TARGET/sysroot"
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)

export PATH="$PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
unset LD_LIBRARY_PATH
unset DYLD_LIBRARY_PATH
unset C_INCLUDE_PATH
unset CPLUS_INCLUDE_PATH
unset LIBRARY_PATH

export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"

copy_sysroot() {
    mkdir -p "$SYSROOT"
    cp -r "libfolistdc/include/." "$SYSROOT/usr/include"
}

configure_zlib() {
    cd build

    if [ ! -f "zlib-${ZLIB_VER}.tar.gz" ]; then
        curl -O https://zlib.net/zlib-${ZLIB_VER}.tar.gz
    fi

    rm -rf zlib
    tar -xzf zlib-${ZLIB_VER}.tar.gz
    mv zlib-${ZLIB_VER} zlib

    cd zlib

    ./configure --prefix="$PREFIX" --static

    cd ../..
}

make_zlib() {
    cd build/zlib

    make -j$PARALLEL
    make install

    cd ../..
}

configure_binutils() {
    cd build

    mkdir -p binutils
    cd binutils

    ../../binutils-strata/configure \
        --target=$TARGET \
        --prefix="$PREFIX" \
        --with-sysroot="$SYSROOT" \
        --disable-nls \
        --disable-werror \
        --enable-static \
        --with-system-zlib

    cd ../..
}

make_binutils() {
    cd build/binutils

    make -j$PARALLEL MAKEINFO=true
    make install MAKEINFO=true

    cd ../..
}

configure_gcc_pass1() {
    cd build

    mkdir -p gcc-pass1
    cd gcc-pass1

    ../../gcc-strata/configure \
        --target=$TARGET \
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
    local GCC_LIB_PATH
    local GCC_INTERNAL_HEADERS_PATH
    local GCC_INTERNAL_FIXED_HEADERS_PATH

    cd build/gcc-pass1

    make -j$PARALLEL all-gcc MAKEINFO=true
    make -j$PARALLEL all-target-libgcc MAKEINFO=true
    make install-gcc MAKEINFO=true
    make install-target-libgcc MAKEINFO=true

    GCC_LIB_PATH=$("$PREFIX/bin/$TARGET-gcc" -print-libgcc-file-name | xargs dirname)
    GCC_INTERNAL_HEADERS_PATH="$GCC_LIB_PATH/include"
    GCC_INTERNAL_FIXED_HEADERS_PATH="$GCC_LIB_PATH/include-fixed"

    mkdir -p "$SYSROOT/usr/include"

    cp -r "$GCC_INTERNAL_HEADERS_PATH"/* "$SYSROOT/usr/include"
    if [ -d "$GCC_INTERNAL_FIXED_HEADERS_PATH" ]; then
        cp -r "$GCC_INTERNAL_FIXED_HEADERS_PATH"/* "$SYSROOT/usr/include"
    fi
    cp -r "../../gcc-strata/gcc/ginclude/stdint-gcc.h" "$SYSROOT/usr/include/stdint.h"

    cd ../..
}

configure_gcc_pass2() {
    cd build

    mkdir -p build/gcc-pass2
    cd build/gcc-pass2

    ../../gcc-strata/configure \
        --target=$TARGET \
        --prefix="$PREFIX" \
        --with-sysroot="$SYSROOT" \
        --with-native-system-header-dir="/usr/include" \
        --with-system-zlib \
        --enable-languages=c \
        --enable-nls \
        --enable-libssp \
        --enable-threads \
        --enable-shared \
        --enable-libgomp \
        --enable-libquadmath \
        --enable-libatomic \
        --enable-lto
    
    cd ../..
}

build_gcc_pass2() {
    cd build/gcc-pass2

    make -j$PARALLEL all-gcc MAKEINFO=true
    make -j$PARALLEL all-target-libgcc MAKEINFO=true
    make install-gcc MAKEINFO=true
    make install-target-libgcc MAKEINFO=true
    
    cd ../..
}

if [ ! -f "build/.sysroot.stamp" ]; then
    copy_sysroot
    touch "build/.sysroot.stamp"
fi

if [ ! -f "build/.configure-zlib.stamp" ]; then
    configure_zlib
    touch "build/.configure-zlib.stamp"
fi

if [ ! -f "build/.zlib.stamp" ]; then
    make_zlib
    touch "build/.zlib.stamp"
fi

if [ ! -f "build/.configure-binutils.stamp" ]; then
    configure_binutils
    touch "build/.configure-binutils.stamp"
fi

if [ ! -f "build/.binutils.stamp" ]; then
    make_binutils
    touch "build/.binutils.stamp"
fi

if [ ! -f "build/.configure-gcc-pass1.stamp" ]; then
    configure_gcc_pass1
    touch "build/.configure-gcc-pass1.stamp"
fi

if [ ! -f "build/.gcc-pass1.stamp" ]; then
    make_gcc_pass1
    touch "build/.gcc-pass1.stamp"
fi

# TODO: build standard C library
