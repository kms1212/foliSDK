class X8664Folisdk < Formula
  desc "Cross-compiler toolchain for foliOS"
  homepage "https://github.com/kms1212/folisdk"
  
  url "file://#{Dir.pwd}/build-x86_64/folisdk-0.0.1.tar.gz"
  
  version "0.0.1"
  sha256 "fc409359e1edeca20126e2bcb84ca4633cfe3fb0ab474713828cbb7738650dcd"
  
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
