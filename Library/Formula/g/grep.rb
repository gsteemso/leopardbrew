class Grep < Formula
  desc 'GNU grep, egrep and fgrep'
  homepage 'https://www.gnu.org/software/grep/'
  url 'https://ftpmirror.gnu.org/grep/grep-3.11.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/grep/grep-3.11.tar.xz'
  sha256 '1db2aedde89d0dea42b16d9528f894c8d15dae4e190b59aecc78f5a951276eab'

  option 'with-default-names', 'Do not prepend “g” to the binaries'
  deprecated_option 'default-names' => 'with-default-names'
  option 'without-nls', 'Do not install with Natural Language Support (internationalization)'

  depends_on 'pkg-config' => :build
  depends_on 'pcre2'
  depends_on :nls => :recommended

  enhanced_by 'libsigsegv'

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
      --with-packager=Leopardbrew
    ]
    args << '--disable-nls' if build.without? 'nls'
    args << '--program-prefix=g' if build.without? 'default-names'

    system './configure', *args
    system 'make'
    system 'make', 'install'
  end # install

  def caveats; <<-EOS.undent
      The command is installed with the prefix “g”.  If you do not want the prefix,
      install using the “--with-default-names” option.
    EOS
  end if build.without? 'default-names'

  test do
    text_file = testpath/'file.txt'
    text_file.write 'This line should be matched'
    cmd = build.with?('default-names') ? 'fgrep' : 'gfgrep'
    grepped = shell_output("#{bin}/#{cmd} match #{text_file}")
    assert_match 'should be matched', grepped
  end # test
end
