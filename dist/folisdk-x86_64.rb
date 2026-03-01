class FolisdkX8664 < Formula
  desc "foliSDK for x86_64"
  homepage "https://github.com/kms1212/folisdk"
  url "file://#{Dir.pwd}/build/folisdk-x86_64.tar.gz"
  version "0.0.1"
  sha256 "3ff0b3aa77d599c73d9bc03d5d4f29d3860cc10f24abc15ed85b3b532e51f13c"

  depends_on "folisdk-host"

  keg_only "it conflicts with standard gdb and binutils"

  def install
    prefix.install Dir["*"]
  end

  def caveats
    <<~EOS
      🚀 foliSDK for x86_64 has been successfully installed!

      This SDK contains a unified toolchain and a rich set of system libraries:
      - Runtime: GCC 15.2.0, musl libc, libstdc++
      - Libraries:
        gmp, mpfr, mpc, nettle, libsodium
        libffi, libuv
        libxml2, libxslt, libexpat, yyjson,
        zlib, zstd, bzip2, xz, lz4, libarchive,
        libiconv, ncurses, editline, readline,
        sqlite3

      The sysroot is located at:
        #{opt_prefix}/x86_64-strata-folios/sysroot

      To use the environment manager, add the following line to your ~/.zshrc or ~/.bash_profile:
        source #{opt_share}/folisdk/folisdk-env.sh

      After reloading your shell, you can activate the SDK using:
        folisdk_activate x86_64

      When building user applications, use the cross-compiler directly:
        x86_64-strata-folios-gcc hello.c -o hello

    EOS
  end
end
