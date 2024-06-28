class TigerOnly < Requirement
  def message; <<-EOS.undent
    gcc-4.2 is only provided for Tiger, as build 5577 is officially available
    with Xcode starting from Leopard.
    EOS
  end
  def satisfied?; MacOS.version == :tiger; end
  def fatal?; true; end
end

class AppleGcc42 < Formula
  desc 'the last Apple version of the GNU Compiler Collection for OS X'
  homepage 'http://https://opensource.apple.com/releases/'
  url 'https://github.com/apple-oss-distributions/gcc/archive/refs/tags/gcc-5666.3.tar.gz'
  version '4.2.1-5666.3'
  sha256 '2e9889ce0136f5a33298cf7cce5247d31a5fb1856e6f301423bde4a81a5e7ea6'

  depends_on TigerOnly

  depends_on 'gmp'
  depends_on 'mpfr'

  keg_only :provided_by_osx if MacOS.version > :tiger

  def install
    args = [
      'RC_OS=macos',
      'RC_ARCHS=ppc i386',
      'TARGETS=ppc i386',
      "SRCROOT=#{buildpath}",
      "OBJROOT=#{buildpath}/build/obj",
      "DSTROOT=#{buildpath}/build/dst",
      "SYMROOT=#{buildpath}/build/sym"
    ]
    mkdir_p ['build/obj', 'build/dst', 'build/sym']
    system 'gnumake', 'install', *args
    doc.install *Dir['build/dst/Developer/Documentation/DocSets/com.apple.ADC_Reference_Library.DeveloperTools.docset/Contents/Resources/Documents/documentation/DeveloperTools/gcc-4.2.1/*']
    bin.install *Dir['build/dst/usr/bin/*']
    include.install 'build/dst/usr/include/gcc' if MacOS.version < :leopard
    lib.install 'build/dst/usr/lib/gcc'
    libexec.install 'build/dst/usr/libexec/gcc'
    man.install 'build/dst/usr/share/man/man1'
  end

  def caveats
    <<-EOS.undent
      This formula brews compilers built from Apple’s GCC sources, build 5666.3 (the
      last available from Apple’s open‐source distributions).  All compilers have a
      “-4.2” suffix.
    EOS
  end

  test do
    (testpath/'hello-c.c').write <<-EOS.undent
      #include <stdio.h>
      int main()
      {
        puts("Hello, world!");
        return 0;
      }
    EOS
    system bin/'gcc-4.2', '-o', 'hello-c', 'hello-c.c'
    assert_equal "Hello, world!\n", `./hello-c`
  end
end
