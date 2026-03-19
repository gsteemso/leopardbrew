require 'compilers'

class Swig < Formula
  desc 'Generate scripting interfaces to C/C++ code'
  homepage 'http://www.swig.org/'
  url 'https://github.com/swig/swig/archive/refs/tags/v4.2.1.tar.gz'
  sha256 '8895878b9215612e73611203dc8f5232c626e4d07ffc4532922f375518f067ca'

  option :universal

  depends_on 'bison' => :build

  depends_on 'pcre2'
  depends_on 'ruby'

  # It will configure itself for these things if they are present, which requires that they appear in the $PATH during the build.
  enhanced_by 'boost'
  enhanced_by 'guile'
  enhanced_by 'lua'
  enhanced_by 'lua51'
  enhanced_by 'perl'
  enhanced_by 'python2'
  enhanced_by 'python3'
  enhanced_by 'tcl-tk'

  def install
    ENV.universal_binary if build.universal?
    system './autogen.sh'
    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking'
    ]
    args << '-disable-cpp11-testing' if ENV.compiler !~ CompilerConstants::GNU_CXX11_REGEXP
    system './configure', *args
    system 'make'
    system 'make', 'install'
  end

  test do
    ENV.universal_binary if build.universal?
    (testpath/'test.c').write <<-EOS.undent
      int add(int x, int y)
      {
        return x + y;
      }
    EOS
    (testpath/'test.i').write <<-EOS.undent
      %module test
      %inline %{
      extern int add(int x, int y);
      %}
    EOS
    (testpath/'run.rb').write <<-EOS.undent
      require './test'
      puts Test.add(1, 1)
    EOS
    system "#{bin}/swig", '-ruby', 'test.i'
    system ENV.cc, '-c', 'test.c'
    system ENV.cc, '-c', 'test_wrap.c', '-I/System/Library/Frameworks/Ruby.framework/Headers/'
    system ENV.cc, '-bundle', '-flat_namespace', '-undefined', 'suppress', 'test.o', 'test_wrap.o', '-o', 'test.bundle'
    assert_equal '2', shell_output('ruby run.rb').strip
  end
end
