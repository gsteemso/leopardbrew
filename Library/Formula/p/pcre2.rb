# stable release 2025-10-21; checked 2026-03-08
class Pcre2 < Formula
  desc 'Perl-compatible regular expressions library with revised API'
  homepage 'https://www.pcre.org/'
  url 'https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.47/pcre2-10.47.tar.bz2'
  sha256 '47fe8c99461250d42f89e6e8fdaeba9da057855d06eb7fc08d9ca03fd08d7bc7'

  head do
    url 'https://github.com/PCRE2Project/pcre2.git'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end

  option :universal

  def install
    ENV.universal_binary if build.universal?
    ENV.deparallelize

    system './autogen.sh' if build.head?

    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-pcre2-16
      --enable-pcre2-32
      --enable-pcre2grep-libz
      --enable-pcre2grep-libbz2
      --enable-pcre2test-libedit
    ]
    args << '--enable-jit' if ENV.supports_feature? :jit

    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end # install

  test do
    arch_system bin/'pcre2grep', 'regular\s+expression', share/'doc/pcre2/README'
  end
end # Pcre2
