class Guile2 < Formula
  desc 'GUILE:  GNU Ubiquitous Intelligent Language for Extensions (legacy version)'
  homepage 'https://www.gnu.org/software/guile/'
  url 'http://ftpmirror.gnu.org/guile/guile-2.2.7.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/guile/guile-2.2.7.tar.lz'
  sha256 ''

  option :universal

  depends_on 'pkg-config' => :build
  depends_on 'bdw-gc'
  depends_on 'gmp'
  depends_on 'libffi'
  depends_on 'libunistring'
  depends_on 'readline'

  # does it still do either of these?  hells if I know
  fails_with :llvm do; build 2336; cause 'Segfaults during compilation'; end
  fails_with :clang do; build 211; cause 'Segfaults during compilation'; end

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make'
    ENV.deparallelize { system 'make', '-i', '-k', 'check' }
    system 'make', 'install'

    # A really messed up workaround required on OS X --mkhl
    Pathname.glob(lib/'*.dylib') do |dylib|
      lib.install_symlink dylib.basename => "#{dylib.basename(".dylib")}.so"
    end

    (share/'gdb/auto-load').install Dir[lib/'*-gdb.scm']
  end # install

  test do
    hello = testpath/'hello.scm'
    hello.write <<-EOS.undent
      (display "Hello World")
      (newline)
    EOS

    ENV['GUILE_AUTO_COMPILE'] = '0'

    arch_system bin/'guile', hello
  end # test
end # Guile2
