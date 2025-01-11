class Libidn2 < Formula
  desc 'International domain name library (IDNA2008, Punycode and UTR 46)'
  homepage 'https://www.gnu.org/software/libidn/#libidn2'
  url 'http://ftpmirror.gnu.org/libidn/libidn2-2.3.7.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/libidn/libidn2-2.3.7.tar.gz'
  sha256 '4c21a791b610b9519b9d0e12b8097bf2f359b12f8dd92647611a929e6bfd7d64'
  license any_of: ['GPL-2.0-or-later', 'LGPL-3.0-or-later']

  bottle do
    sha256 "eefd238f08db025045214510e64a3a0c9d075cf8cb0d3aef1ae72ad29e591d61" => :tiger_altivec
  end

  head do
    url 'https://gitlab.com/libidn/libidn2.git', branch: 'master'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'gengetopt' => :build
    depends_on 'gettext' => :build
    depends_on 'help2man' => :build
    depends_on 'libtool' => :build
    # depends on Ruby gem “ronn”
  end

  option :universal

  depends_on 'pkg-config' => :build
  depends_on 'gettext'
  depends_on 'libunistring'

  enhanced_by 'libiconv'

  def install
    ENV.universal_binary if build.universal?

    args = [
      "--prefix=#{prefix}",
      '--disable-silent-rules',
      '--with-packager=Homebrew'
    ]

    system './bootstrap', '--skip-po' if build.head?
    system './configure', *args
    system 'make', 'install'
  end

  test do
    ENV.delete('LC_CTYPE')
    ENV['CHARSET'] = 'UTF-8'
    output = shell_output("#{bin}/idn2 räksmörgås.se")
    assert_equal 'xn--rksmrgs-5wao1o.se', output.chomp
    output = shell_output("#{bin}/idn2 blåbærgrød.no")
    assert_equal 'xn--blbrgrd-fxak7p.no', output.chomp
  end
end
