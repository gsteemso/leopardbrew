class Readline < Formula
  desc "Library for command-line editing"
  homepage "https://tiswww.case.edu/php/chet/readline/rltop.html"
  url "http://ftpmirror.gnu.org/readline/readline-8.2.13.tar.gz"
  mirror "https://ftp.gnu.org/gnu/readline/readline-8.2.13.tar.gz"
  sha256 '0e5be4d2937e8bd9b7cd60d46721ce79f88a33415dd68c2d738fb5924638f656'
  revision 1

  keg_only :shadowed_by_osx, <<-EOS.undent
    OS X provides the BSD libedit library, which shadows libreadline.
    In order to prevent conflicts when programs look for libreadline we are
    defaulting this GNU Readline installation to keg-only.
  EOS

  def install
    ENV.universal_binary
    # Since we don't set any CFLAGS, readline adds some
    # which break the build as they're not supported by GCC 4.2
    ENV.append_to_cflags "-g -Os" if ENV.compiler == :gcc
    system "./configure", "--prefix=#{prefix}", "--enable-multibyte"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <stdio.h>
      #include <stdlib.h>
      #include <readline/readline.h>

      int main()
      {
        printf("%s\\n", readline("test> "));
        return 0;
      }
    EOS
    ENV.universal_binary
    system ENV.cc, "test.c", "-lreadline", "-o", "test"
    assert_equal "Hello, World!", pipe_output("./test", "Hello, World!\n").strip
  end
end
