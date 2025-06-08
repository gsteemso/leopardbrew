# NOTE: Configure will fail if using awk 20110810 from dupes.
# Upstream issue: https://savannah.gnu.org/bugs/index.php?37063

class Wget < Formula
  desc 'Internet file retriever'
  homepage 'https://www.gnu.org/software/wget/'
  url 'http://ftpmirror.gnu.org/wget/wget-1.25.0.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.lz'
  sha256 '19225cc756b0a088fc81148dc6a40a0c8f329af7fd8483f1c7b2fe50f4e08a1f'

  head do
    url 'https://git.savannah.gnu.org/wget.git'
    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
  end

  deprecated_option 'enable-iri' => nil
  deprecated_option 'with-iri' => nil
  deprecated_option 'enable-debug' => 'with-debug'

  option 'with-debug', 'Build with debug support'
  option 'with-ssl=',  'Choose gnutls, libressl, or openssl security (required)'

  depends_on 'pkg-config' => :build
  depends_on 'gettext'
  depends_on 'libidn2'
  depends_on 'libunistring'
  depends_on 'zlib'
  @ssl_lib = ''
  case (ARGV.value('with-ssl') || @ssl_lib).downcase
    when /^gnu/   then depends_on (@ssl_lib = 'gnutls')
    when /^libre/ then depends_on (@ssl_lib = 'libressl')
    else depends_on (@ssl_lib = 'openssl3')
#    else raise MissingParameterError, 'You must specify a transport security library using “--with-ssl=”.'
  end
  depends_on 'libpsl'   => :recommended
  depends_on 'pcre2'    => :recommended
  depends_on 'c-ares'      => :optional
  depends_on 'gpgme'       => :optional
  depends_on 'libmetalink' => :optional

  def install
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
    ]
    args << '--disable-debug' if build.without? 'debug'
    if @ssl_lib != 'gnutls'
      args << '--with-ssl=openssl'
      args << "--with-libssl-prefix=#{Formula[(@ssl_lib == 'libressl') \
                                               ? 'libressl'            \
                                               : 'openssl3'            \
                                             ].opt_prefix}"
    end # without gnutls (→ with libressl or openssl3)
    args << '--with-cares' if build.with? 'c-ares'
    # gpgme gets picked up unaided if specified
    args << '--with-metalink' if build.with? 'libmetalink'
    args << '--disable-psl' if build.without? 'libpsl'
    args << '--disable-pcre2' if build.without? 'pcre2'
    system './bootstrap' if build.head?
    system './configure', *args
    system 'make', 'install'
  end # install

  test { system "#{bin}/wget", '-O', "github-dot-com.html", 'https://github.com' }
end # Wget
