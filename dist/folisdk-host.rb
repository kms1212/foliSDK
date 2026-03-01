class FolisdkHost < Formula
  desc "foliSDK Host Utilities"
  homepage "https://github.com/kms1212/folisdk"
  url "file://#{Dir.pwd}/build/folisdk-host.tar.gz"
  version "0.0.1"
  sha256 "3ff0b3aa77d599c73d9bc03d5d4f29d3860cc10f24abc15ed85b3b532e51f13c"
  
  keg_only "it conflicts with standard cmake"

  def install
    prefix.install Dir["*"]

    (share/"folisdk").mkpath
    (share/"folisdk/folisdk-env.sh").write <<~EOS
      # ==========================================
      # foliSDK Environment Manager
      # ==========================================

      folisdk_activate() {
          local arch=""
          local path_only="false"

          for arg in "$@"; do
              case $arg in
                  --path-only)
                      path_only=true
                      shift
                      ;;
                  *)
                      arch="${arg}"
                      ;;
              esac
          done

          if [ -z "$arch" ]; then
              echo "❌ Error: No architecture specified"
              return 1
          fi

          local target="${arch}-strata-folios"
          local host_prefix="#{opt_prefix}"
          local arch_prefix="#{opt_prefix}/../folisdk-${arch}"
          local sdk_host_bin="${host_prefix}/bin"
          local sdk_arch_bin="${arch_prefix}/bin"
          local sysroot="${arch_prefix}/${target}/sysroot"

          if [ ! -d "$sdk_host_bin" ]; then
              echo "❌ Error: foliSDK is improperly installed"
              return 1
          fi

          if [ ! -d "$sdk_arch_bin" ]; then
              echo "❌ Error: foliSDK not found at $arch_prefix"
              return 1
          fi

          if [ -n "$FOLISDK_ACTIVE" ]; then
              folisdk_deactivate
          fi

          export _OLD_FOLISDK_PATH="$PATH"
          export _OLD_FOLISDK_PS1="$PS1"

          export PATH="${sdk_host_bin}:${sdk_arch_bin}:$PATH"
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

              export _OLD_FOLISDK_CROSS_COMPILE="$CROSS_COMPILE"
              export _OLD_FOLISDK_CC="$CC"
              export _OLD_FOLISDK_CXX="$CXX"
              export _OLD_FOLISDK_AS="$AS"
              export _OLD_FOLISDK_LD="$LD"
              export _OLD_FOLISDK_NM="$NM"
              export _OLD_FOLISDK_STRIP="$STRIP"
              export _OLD_FOLISDK_AR="$AR"
              export _OLD_FOLISDK_RANLIB="$RANLIB"

              export _OLD_FOLISDK_SYSROOT="$SYSROOT"
              export _OLD_FOLISDK_PKG_CONFIG_DIR="$PKG_CONFIG_DIR"
              export _OLD_FOLISDK_PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR"
              export _OLD_FOLISDK_PKG_CONFIG_SYSROOT_DIR="$PKG_CONFIG_SYSROOT_DIR"
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

          unset CROSS_COMPILE CC CXX AS LD NM STRIP AR RANLIB
          unset SYSROOT PKG_CONFIG_DIR PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR

          if [ -n "$_OLD_FOLISDK_CROSS_COMPILE" ]; then
              export CROSS_COMPILE="$_OLD_FOLISDK_CROSS_COMPILE"
          fi
          if [ -n "$_OLD_FOLISDK_CC" ]; then
              export CC="$_OLD_FOLISDK_CC"
          fi
          if [ -n "$_OLD_FOLISDK_CXX" ]; then
              export CXX="$_OLD_FOLISDK_CXX"
          fi
          if [ -n "$_OLD_FOLISDK_AS" ]; then
              export AS="$_OLD_FOLISDK_AS"
          fi
          if [ -n "$_OLD_FOLISDK_LD" ]; then
              export LD="$_OLD_FOLISDK_LD"
          fi
          if [ -n "$_OLD_FOLISDK_NM" ]; then
              export NM="$_OLD_FOLISDK_NM"
          fi
          if [ -n "$_OLD_FOLISDK_STRIP" ]; then
              export STRIP="$_OLD_FOLISDK_STRIP"
          fi
          if [ -n "$_OLD_FOLISDK_AR" ]; then
              export AR="$_OLD_FOLISDK_AR"
          fi
          if [ -n "$_OLD_FOLISDK_RANLIB" ]; then
              export RANLIB="$_OLD_FOLISDK_RANLIB"
          fi

          if [ -n "$_OLD_FOLISDK_SYSROOT" ]; then
              export SYSROOT="$_OLD_FOLISDK_SYSROOT"
          fi
          if [ -n "$_OLD_FOLISDK_PKG_CONFIG_DIR" ]; then
              export PKG_CONFIG_DIR="$_OLD_FOLISDK_PKG_CONFIG_DIR"
          fi
          if [ -n "$_OLD_FOLISDK_PKG_CONFIG_LIBDIR" ]; then
              export PKG_CONFIG_LIBDIR="$_OLD_FOLISDK_PKG_CONFIG_LIBDIR"
          fi
          if [ -n "$_OLD_FOLISDK_PKG_CONFIG_SYSROOT_DIR" ]; then
              export PKG_CONFIG_SYSROOT_DIR="$_OLD_FOLISDK_PKG_CONFIG_SYSROOT_DIR"
          fi

          unset _OLD_FOLISDK_PATH
          unset _OLD_FOLISDK_PS1
          unset FOLISDK_ACTIVE
          
          unset _OLD_FOLISDK_CROSS_COMPILE
          unset _OLD_FOLISDK_CC
          unset _OLD_FOLISDK_CXX
          unset _OLD_FOLISDK_AS
          unset _OLD_FOLISDK_LD
          unset _OLD_FOLISDK_NM
          unset _OLD_FOLISDK_STRIP
          unset _OLD_FOLISDK_AR
          unset _OLD_FOLISDK_RANLIB

          unset _OLD_FOLISDK_SYSROOT
          unset _OLD_FOLISDK_PKG_CONFIG_DIR
          unset _OLD_FOLISDK_PKG_CONFIG_LIBDIR
          unset _OLD_FOLISDK_PKG_CONFIG_SYSROOT_DIR

          echo "🛑 Deactivated foliSDK. Returned to host environment."
      }
    EOS
  end

  def caveats
    <<~EOS
      🚀 foliSDK Host Utilities have been successfully installed!

      To use the environment manager, add the following line to your ~/.zshrc or ~/.bash_profile:
        source #{opt_share}/folisdk/folisdk-env.sh

      After reloading your shell, you can activate the SDK using:
        folisdk_activate <arch>
        e.g. folisdk_activate x86_64

    EOS
  end
end
