# stable release 2021-09-25; checked 2025-10-19
class Bison < Formula
  desc 'Parser generator'
  homepage 'https://www.gnu.org/software/bison/'
  url 'http://ftpmirror.gnu.org/bison/bison-3.8.2.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.lz'
  sha256 'fdf98bfe82abb04a34d4356753f7748dbbd2ef1221b1f202852a2b5ce0f78534'

  keg_only :provided_by_osx, 'Some formulæ require a newer version of bison.'

  bottle do
    sha256 '7a9139192cc1d0e5768b80e1857651daafdc708ad1e379a4c050dca324a248af' => :tiger_altivec
  end

  option :tests

  if MacOS.version < :leopard
    # GNU M4 1.4.6 or later is required; 1.4.16 or newer is recommended.  Tiger comes with 1.4.2.
    depends_on 'm4'
  end
  if build.with? 'tests'
    depends_on 'readline'
  else
    enhanced_by 'readline'
  end
  enhanced_by 'libiconv'
  enhanced_by :nls

  def install
    args = %W[
        --prefix=#{prefix}
        --disable-dependency-tracking
        --disable-silent-rules
      ]
    args << '--disable-year2038' unless Target.pure_64b?
    system './configure', *args
    system 'make'
    system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'
  end

  test do
    (testpath/'test.y').write <<-EOS.undent
      %{ #include <iostream>
         using namespace std;
         extern void yyerror (char *s);
         extern int yylex ();
      %}
      %start prog
      %%
      prog:  //  empty
          |  prog expr '\\n' { cout << "pass"; exit(0); }
          ;
      expr: '(' ')'
          | '(' expr ')'
          |  expr expr
          ;
      %%
      char c;
      void yyerror (char *s) { cout << "fail"; exit(0); }
      int yylex () { cin.get(c); return c; }
      int main() { yyparse(); }
    EOS
    system bin/'bison', 'test.y'
    system ENV.cxx, 'test.tab.c', '-o', 'test'
    assert_equal 'pass', shell_output("echo \"((()(())))()\" | ./test")
    assert_equal 'fail', shell_output("echo \"())\" | ./test")
  end # test
end # Bison
