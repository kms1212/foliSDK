class X86Folisdk < Formula
  desc "Cross-compiler toolchain for foliOS"
  homepage "https://github.com/kms1212/folisdk"
  
  url "file://#{Dir.pwd}/build/folisdk.tar.gz"
  
  version "0.0.1"
  sha256 "ce6975624fe43bab36219b2d280878465b48dae1341f6bd88af78022f347d241"
  
  keg_only "it conflicts with standard gdb and binutils"

  def install
    prefix.install Dir["*"]
  end

  def caveats
    <<~EOS
      foliOS SDK for x86 (i686 & x86_64) has been installed.

      This SDK contains a unified toolchain and a rich set of system libraries:
      - Archs:   i686-strata-folios, x86_64-strata-folios
      - Runtime: GCC 15.2.0, musl libc, libstdc++
      - Libraries:
        gmp, mpfr, mpc, nettle, libsodium
        libffi, libuv
        libxml2, libxslt, libexpat, yyjson,
        zlib, zstd, bzip2, xz, lz4, libarchive,
        libiconv, ncurses, editline, readline,
        sqlite3

      The sysroots for each architecture are located at:
        i686:   #{opt_prefix}/i686-strata-folios/sysroot
        x86_64: #{opt_prefix}/x86_64-strata-folios/sysroot

      When building user applications, use the cross-compiler directly:
        i686-strata-folios-gcc hello.c -o hello
        x86_64-strata-folios-gcc hello.c -o hello
    EOS
  end
end
