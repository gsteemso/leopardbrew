class Readline < Formula
  desc 'Library for command-line editing'
  homepage 'https://tiswww.case.edu/php/chet/readline/rltop.html'
  url 'http://ftpmirror.gnu.org/readline/readline-8.3.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz'
  version '8.3.1'
  sha256 'fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc'

  keg_only :shadowed_by_osx, <<-EOS.undent
    OS X provides the BSD libedit library, which shadows libreadline.
    In order to prevent conflicts when programs look for libreadline we are
    defaulting this GNU Readline installation to keg-only.
  EOS

  patch :p0 do
    url 'https://ftpmirror.gnu.org/readline/readline-8.3-patches/readline83-001'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.3-patches/readline83-001'
    sha256 '21f0a03106dbe697337cd25c70eb0edbaa2bdb6d595b45f83285cdd35bac84de'
  end

  def install
    ENV.universal_binary
    system './configure', "--prefix=#{prefix}", '--enable-multibyte'
    system 'make', 'install'
  end

  test do
    (testpath/'test.c').write <<-EOS.undent
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
    system ENV.cc, 'test.c', '-lreadline', '-o', 'test'
    assert_equal 'Hello, World!', pipe_output('./test', "Hello, World!\n").strip
  end
end
