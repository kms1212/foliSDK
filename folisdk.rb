class Folisdk < Formula
  desc "Cross-compiler toolchain for foliOS"
  homepage "https://github.com/kms1212/folisdk"
  
  url "file://#{Dir.pwd}/build/folisdk-0.0.1.tar.gz"
  
  version "0.0.1"
  sha256 "b41ac4b352eaa37411e6da14d4b950034c1ece11fb93d459e673f6f6e485e945"
  
  keg_only "it conflicts with standard gdb and binutils"

  def install
    prefix.install Dir["*"]
  end

  def caveats
    <<~EOS
      Installed:
      - gcc (C, C++)
      - binutils
      - gdb
      - musl libc
    EOS
  end
end
