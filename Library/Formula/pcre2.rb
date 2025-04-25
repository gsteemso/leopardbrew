class Pcre2 < Formula
  desc 'Perl-compatible regular expressions library with revised API'
  homepage 'https://www.pcre.org/'
  url 'https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.bz2'
  sha256 '21547f3516120c75597e5b30a992e27a592a31950b5140e7b8bfde3f192033c4'

  head do
    url 'https://github.com/PCRE2Project/pcre2'

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
    # PPC64 JIT is explicitly supported in the package’s source code, but for reasons yet to be
    # determined, fails to build properly under Mac OS 10.5.
    args << '--enable-jit' unless CPU.powerpc? and MacOS.prefer_64_bit?

    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end # install

  test do
    arch_system bin/'pcre2grep', 'regular expression', share/'doc/pcre2/README'
  end
end # Pcre2
