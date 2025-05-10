# NOTE: Configure will fail if using awk 20110810 from dupes.
# Upstream issue: https://savannah.gnu.org/bugs/index.php?37063

class Wget < Formula
  desc 'Internet file retriever'
  homepage 'https://www.gnu.org/software/wget/'
  url 'http://ftpmirror.gnu.org/wget/wget-1.24.5.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/wget/wget-1.24.5.tar.gz'
  sha256 'fa2dc35bab5184ecbc46a9ef83def2aaaa3f4c9f3c97d4bd19dcb07d4da637de'

  head do
    url 'https://git.savannah.gnu.org/wget.git'
    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
  end

  deprecated_option 'enable-iri' => nil
  deprecated_option 'with-iri' => nil
  deprecated_option 'enable-debug' => 'with-debug'

  option :universal
  option 'with-debug', 'Build with debug support'
  option 'with-libressl', 'Build with LibreSSL security (replaces gnutls)'
  option 'with-openssl3', 'Build with OpenSSL security (replaces gnutls)'

  depends_on 'libpsl'   => :recommended
  depends_on 'pcre2'    => :recommended
  depends_on 'c-ares'       => :optional
  depends_on 'gpgme'        => :optional
  depends_on 'libmetalink'  => :optional
  depends_on 'libressl'     => :optional
  depends_on 'openssl3'     => :optional
  depends_on 'gnutls' if build.without? 'libressl' and build.without? 'openssl3'
  depends_on 'gettext'
  depends_on 'libidn2'
  depends_on 'libunistring'
  depends_on 'pkg-config'
  depends_on 'zlib'

  def install
    ENV.universal_binary if build.universal?
    raise 'Only one SSL backend can be used.  OpenSSL and LibreSSL have both been specified.' \
                                                if build.with? 'libressl' and build.with? 'openssl3'
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
    ]
    args << '--disable-debug' if build.without? 'debug'
    if build.with? 'libressl' or build.with? 'openssl3'
      args << '--with-ssl=openssl'
      args << "--with-libssl-prefix=#{Formula[build.with?('libressl') \
                                               ? 'libressl' \
                                               : 'openssl3' \
                                             ].opt_prefix}"
    end # with libressl or openssl3
    args << '--with-cares' if build.with? 'c-ares'
    # gpgme gets picked up unaided if specified
    args << '--with-metalink' if build.with? 'libmetalink'
    args << '--disable-psl' if build.without? 'libpsl'
    args << '--disable-pcre2' if build.without? 'pcre2'
    system './bootstrap' if build.head?
    system './configure', *args
    system 'make', 'install'
  end # install

  test do
    system bin/'wget', '-O', '-', 'https://github.com'
  end
end

__END__
