class Folisdk < Formula
  desc "Cross-compiler toolchain for foliOS"
  homepage "https://github.com/kms1212/folisdk"
  
  url "file://#{Dir.pwd}/build/folisdk-0.0.1.tar.gz"
  
  version "0.0.1"
  sha256 "a9db594d4edb7ff75545c1dfb600e5648ae1b673217d40bec07b389ea7de63cb"
  
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
