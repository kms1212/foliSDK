class X86Folisdk < Formula
  desc "Cross-compiler toolchain for foliOS"
  homepage "https://github.com/kms1212/folisdk"
  
  url "file://#{Dir.pwd}/build/folisdk.tar.gz"
  
  version "0.0.1"
  sha256 "13d1d171690bbfc6a6be918cfaf00c4234f51d90e7b571fd4f759b6c9077cf53"
  
  keg_only "it conflicts with standard gdb and binutils"

  def install
    prefix.install Dir["*"]

    (share/"folisdk").mkpath
    (share/"folisdk/folisdk-env.sh").write <<~EOS
      # ==========================================
      # foliSDK Environment Manager
      # ==========================================

      folisdk_activate() {
          local arch="x86_64"
          local path_only="false"

          for arg in "$@"; do
              case $arg in
                  --arch=*)
                      arch="${arg#*=}"
                      shift
                      ;;
                  --path-only)
                      path_only=true
                      shift
                      ;;
                  *)
                      return 1
                      ;;
              esac
          done

          local target="${arch}-strata-folios"
          local prefix="#{opt_prefix}"
          local sdk_bin="${prefix}/bin"
          local sysroot="${prefix}/${target}/sysroot"

          if [ ! -d "$sdk_bin" ]; then
              echo "❌ Error: foliSDK not found at $prefix"
              return 1
          fi

          if [ -n "$FOLISDK_ACTIVE" ]; then
              folisdk_deactivate
          fi

          export _OLD_FOLISDK_PATH="$PATH"
          export _OLD_FOLISDK_PS1="$PS1"

          export PATH="${sdk_bin}:$PATH"
          export FOLISDK_ACTIVE="${arch}"
          
          if [ "$path_only" = "false" ]; then
              export CROSS_COMPILE="${target}-"
              export CC="${target}-gcc"
              export CXX="${target}-g++"
              export AS="${target}-as"
              export LD="${target}-ld"
              export NM="${target}-nm"
              export STRIP="${target}-strip"
              export AR="${target}-ld -r -o"
              export RANLIB="true"
              
              export SYSROOT="$sysroot"
              export PKG_CONFIG_DIR=""
              export PKG_CONFIG_LIBDIR="${sysroot}/usr/lib/pkgconfig:${sysroot}/usr/share/pkgconfig"
              export PKG_CONFIG_SYSROOT_DIR="${sysroot}"
          fi

          export PS1="(folisdk-${arch}) $PS1"
          
          echo "✅ Activated foliSDK for architecture: ${arch}"
      }

      folisdk_deactivate() {
          if [ -z "$FOLISDK_ACTIVE" ]; then
              echo "⚠️ foliSDK is not currently active."
              return 1
          fi

          export PATH="$_OLD_FOLISDK_PATH"
          if [ -n "$_OLD_FOLISDK_PS1" ]; then
              export PS1="$_OLD_FOLISDK_PS1"
          fi

          unset _OLD_FOLISDK_PATH
          unset _OLD_FOLISDK_PS1
          unset FOLISDK_ACTIVE
          
          unset CROSS_COMPILE CC CXX AS LD NM STRIP AR RANLIB
          unset SYSROOT PKG_CONFIG_DIR PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR

          echo "🛑 Deactivated foliSDK. Returned to host environment."
      }
    EOS
  end

  def caveats
    <<~EOS
      🚀 foliSDK for x86(i686 & x86_64) has been successfully installed!

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

      To use the environment manager, add the following line to your ~/.zshrc or ~/.bash_profile:
        source #{opt_share}/folisdk/folisdk-env.sh

      After reloading your shell, you can activate the SDK using:
        folisdk_activate --arch=x86_64
        folisdk_activate --arch=i686

    EOS
  end
end
