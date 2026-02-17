class I686Folisdk < Formula
  desc "Cross-compiler toolchain for foliOS"
  homepage "https://github.com/kms1212/folisdk"
  
  url "file://#{Dir.pwd}/build-i686/folisdk-0.0.1.tar.gz"
  
  version "0.0.1"
  sha256 "62630c0649017ab534a9f6aa4cb92fa861e322347c640db06b83892c104ad0ea"
  
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
