class Guile20 < Formula
  desc 'GNU Ubiquitous Intelligent Language for Extensions, legacy version 2.0'
  homepage 'https://www.gnu.org/software/guile/'
  url 'http://ftpmirror.gnu.org/guile/guile-2.0.14.tar.xz'
  mirror 'https://ftp.gnu.org/pub/gnu/guile/guile-2.0.14.tar.xz'
  sha256 'e8442566256e1be14e51fc18839cd799b966bc5b16c6a1d7a7c35155a8619d82'

  option :universal
  option 'without-tests', 'Skip the build-time unit tests'

  depends_on 'pkg-config' => :build
  depends_on 'bdw-gc'
  depends_on 'gmp'
  depends_on 'libffi'
  depends_on 'libunistring'
  depends_on 'readline'
  depends_on :nls => :recommended

  # does it still do either of these?  hells if I know
  fails_with :llvm do; build 2336; cause 'Segfaults during compilation'; end
  fails_with :clang do; build 211; cause 'Segfaults during compilation'; end

  conflicts_with "guile", :because => "they install the same binaries"

  def install
    ENV.universal_binary if build.universal?
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --with-threads
    ]
    args << '--disable-nls' if build.without? 'nls'
    system './configure', *args
    system 'make'
    ENV.deparallelize do
      begin
        safe_system 'make', '-ik', 'check'
      rescue ErrorDuringExecution
        opoo 'Some of the unit tests did not complete successfully.',
          'This is not unusual.  If you ran Leopardbrew in “verbose” mode, the fraction of',
          'tests which failed will be visible in the text above; only you can say whether',
          'the pass rate shown there counts as “good enough”.'
      end
    end if build.with? 'tests'
    system 'make', 'install'
    # A really messed up workaround required on OS X --mkhl
    Pathname.glob("#{lib}/*.dylib") do |dylib|
      lib.install_symlink dylib.basename => "#{dylib.basename('.dylib')}.so"
    end
    (share/'gdb/auto-load').install Dir["#{lib}/*-gdb.scm"]
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
end # Guile20
