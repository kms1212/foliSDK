class Folisdk < Formula
  desc "Cross-compiler toolchain for Strata OS"
  homepage "https://github.com/kms1212/folisdk"
  
  url "file://#{Dir.pwd}/folisdk-1.0.0.tar.gz"
  
  version "1.0.0"
  
  keg_only "it conflicts with standard gdb and binutils"

  def install
    prefix.install Dir["*"]
  end

  def caveats
    <<~EOS
      To use the Folio OS toolchain, you need to add it to your PATH:

        export PATH="#{opt_bin}:$PATH"

      You can add this line to your ~/.zshrc or ~/.bash_profile.
    EOS
  end
end
