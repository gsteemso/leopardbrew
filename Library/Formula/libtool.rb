class Libtool < Formula
  desc 'Generic library support script'
  homepage 'https://www.gnu.org/software/libtool/'
  url 'http://ftpmirror.gnu.org/libtool/libtool-2.5.4.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/libtool/libtool-2.5.4.tar.xz'
  sha256 'f81f5860666b0bc7d84baddefa60d1cb9fa6fceb2398cc3baca6afaa60266675'

  keg_only :provided_until_xcode43

  option :universal
  option 'with-tests', 'Run the build‐time unit tests (very slow)'

  depends_on 'autoconf' => :run
  depends_on 'automake' => :run
  depends_on 'gettext' if build.with? 'tests'

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--program-prefix=g',
                          '--disable-dependency-tracking',
                          '--enable-ltdl-install'
    system 'make'
    bombproof_system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'
  end

  def caveats; <<-EOS.undent
      In order to prevent conflicts with Apple’s stock libtool, we prepend a “g” to
      get “glibtool” and “glibtoolize”.
    EOS
  end

  test do
    system bin/'glibtool', 'execute', '/usr/bin/true'  # glibtool is a script – no archs!
  end
end
