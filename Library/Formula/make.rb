class Make < Formula
  desc 'Utility for directing compilation'
  homepage 'https://www.gnu.org/software/make/'
  url 'http://ftpmirror.gnu.org/make/make-4.4.1.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/make/make-4.4.1.tar.lz'
  sha256 '8814ba072182b605d156d7589c19a43b89fc58ea479b9355146160946f8cf6e9'

  option :universal
  option 'with-checks', 'Run the build‐time unit tests (requires Perl)'
  option 'with-default-names', 'Do not prepend ‘g’ to the binary'

  depends_on 'gettext'
  depends_on 'guile' => :optional
  depends_on 'perl' if build.with? 'checks'
  depends_on 'pkg-config' if build.with? 'guile'

  def install
    ENV.universal_binary if build.universal?
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --prefix=#{prefix}
    ]
    args << '--with-guile' if build.with? 'guile'
    args << '--program-prefix=g' if build.without? 'default-names'
    system './configure', *args
    system 'make'
    system 'make', 'check' if build.with? 'checks'
    system 'make', 'install'
  end # install

  test do
    (testpath/'Makefile').write <<-EOS.undent
      default:
      \t@echo Homebrew
    EOS

    cmd = build.with?('default-names') ? 'make' : 'gmake'

    for_archs bin/cmd do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', "#{a.to_s} "])
      assert_equal "Homebrew\n", shell_output("#{arch_cmd * ' '}#{bin}/#{cmd}")
    end
  end # test
end # Make
