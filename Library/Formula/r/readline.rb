# stable release (latest patch) 2025-12-10; checked 2026-07-22
class Readline < Formula
  desc 'Library for command-line editing'
  homepage 'https://tiswww.case.edu/php/chet/readline/rltop.html'
  url 'http://ftpmirror.gnu.org/readline/readline-8.3.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz'
  version '8.3.3'
  sha256 'fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc'

  keg_only :shadowed_by_osx, <<-EOS.undent.rewrap
    Mac OS provides the BSD libedit library, which shadows libreadline.  To prevent conflicts when programs look for libreadline,
    we have made this GNU Readline installation keg-only.
  EOS

  patch :p0 do
    url 'https://ftpmirror.gnu.org/readline/readline-8.3-patches/readline83-001'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.3-patches/readline83-001'
    sha256 '21f0a03106dbe697337cd25c70eb0edbaa2bdb6d595b45f83285cdd35bac84de'
  end

  patch :p0 do
    url 'https://ftpmirror.gnu.org/readline/readline-8.3-patches/readline83-002'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.3-patches/readline83-002'
    sha256 'e27364396ba9f6debf7cbaaf1a669e2b2854241ae07f7eca74ca8a8ba0c97472'
  end

  patch :p0 do
    url 'https://ftpmirror.gnu.org/readline/readline-8.3-patches/readline83-003'
    mirror 'https://ftp.gnu.org/gnu/readline/readline-8.3-patches/readline83-003'
    sha256 '72dee13601ce38f6746eb15239999a7c56f8e1ff5eb1ec8153a1f213e4acdb29'
  end

  def install
    ENV.universal_binary
    # If $MACOSX_DEPLOYMENT_TARGET defaults to an especially early value (like “10.1”), the linker flag “-undefined dynamic_lookup”
    # gets rejected.  This can only happen for a :ppc build, as anything else requires at least Mac OS Tiger.  The variable has not
    # been in current use since Mac OS Leopard, so we’ll avoid setting it at all on newer systems.
    ENV['MACOSX_DEPLOYMENT_TARGET'] = MacOS.version.to_s if MacOS.version <= :snow_leopard
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
    for_archs('./test') do |_, cmd_array|
      assert_equal 'Hello, World!', pipe_output(cmd_array * ' ', "Hello, World!\n").strip
    end
  end
end
