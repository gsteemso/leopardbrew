# stable release 2025-03-08; checked 2025-08-06
class Libidn2 < Formula
  desc 'International domain name library (IDNA2008, Punycode and UTR 46)'
  homepage 'https://www.gnu.org/software/libidn/#libidn2'
  url 'http://ftpmirror.gnu.org/libidn/libidn2-2.3.8.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz'
  sha256 'f557911bf6171621e1f72ff35f5b1825bb35b52ed45325dcdee931e5d3c0787a'
  license any_of: ['GPL-2.0-or-later', 'LGPL-3.0-or-later']

  head do
    url 'https://gitlab.com/libidn/libidn2.git', branch: 'master'

    depends_on 'autoconf'  => :build
    depends_on 'automake'  => :build
    depends_on 'gengetopt' => :build
    depends_on 'gettext'   => :build
    depends_on 'help2man'  => :build
    depends_on 'libtool'   => :build
    depends_on LanguageModuleRequirement.new('ruby', 'ronn')
  end

  option :universal

  depends_on 'pkg-config'   => :build
  depends_on 'libunistring'
  depends_on :nls           => :recommended

  enhanced_by 'libiconv'

  def install
    ENV.universal_binary if build.universal?

    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking',
      '--disable-silent-rules',
      '--with-packager=Leopardbrew'
    ]
    args << '--disable-nls' if build.without? :nls
    args << '--enable-year2038' if Target.pure_64b?
    args << "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}" if active_enhancements.include? 'libiconv'

    system './bootstrap', '--skip-po' if build.head?
    system './configure', *args
    system 'make'
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
