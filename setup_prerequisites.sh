#!/bin/bash

set -e

cd gcc-strata
./contrib/download_prerequisites
cd ..

cd binutils-strata
ln -s gcc-strata/gmp gmp
ln -s gcc-strata/mpfr mpfr
ln -s gcc-strata/mpc mpc
ln -s gcc-strata/isl isl
cd ..
