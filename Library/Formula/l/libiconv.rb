# stable release 2026-03-07; checked 2026-07-22
class Libiconv < Formula
  desc 'Conversion library'
  homepage 'https://www.gnu.org/software/libiconv/'
  url 'https://ftpmirror.gnu.org/libiconv/libiconv-1.19.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/libiconv/libiconv-1.19.tar.gz'
  sha256 '88dd96a8c0464eca144fc791ae60cd31cd8ee78321e67397e25fc095c4a19aa6'

  keg_only :provided_by_osx

  option :universal
  option 'with-tests', 'Run the build-time unit tests (strongly recommended for the first install, but a bit slow)'

  depends_on 'autoconf' => :build
  depends_on 'automake' => :build
  depends_on 'gettext'

  def install
    ENV.universal_binary if build.universal?
    ENV.deparallelize
    system './configure', "--prefix=#{prefix}",
                          '--disable-debug',
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-extra-encodings',
                          '--enable-static',
                          "--docdir=#{doc}"
    system 'make'
    system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'
  end

  def caveats; <<-_.undent
      GNU Libiconv and GNU Gettext are circularly interdependent.  {libiconv} depends
      explicitly on {gettext} – which means that {gettext} will be brewed for you, if
      it wasn’t already, when you brew {libiconv}.  The reverse can’t be done because
      of the circular dependency.

      TL,DR:  To ensure both packages work correctly, once {libiconv} has been brewed,
      you should `brew reinstall gettext`.

      (They should be brewed in this order because Mac OS does include a very basic –
      if outdated – libiconv, but has never included gettext.)
    _
  end

  test do
    arch_system bin/'iconv', '--help'
  end
end
