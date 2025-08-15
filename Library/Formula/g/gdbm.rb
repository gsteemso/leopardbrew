# stable release 2025-07-31; checked 2025-08-04
class Gdbm < Formula
  desc 'GNU database manager'
  homepage 'https://www.gnu.org/software/gdbm/'
  url 'http://ftpmirror.gnu.org/gdbm/gdbm-1.26.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/gdbm/gdbm-1.26.tar.gz'
  sha256 '6a24504a14de4a744103dcb936be976df6fbe88ccff26065e54c1c47946f4a5e'

  # Technically only true if built with libgdbm-compat, but conditional keg‐onliness leads to chaos.
  keg_only :shadowed_by_osx

  option :universal
  option 'without-libgdbm-compat', 'Omit the libgdbm_compat library, which provides old‐style dbm/ndbm interfaces'

  depends_on 'autoconf' => :build
  depends_on 'automake' => :build
  depends_on 'm4'       => :build

  depends_on 'coreutils'
  depends_on 'readline'
  depends_on :nls       => :recommended

  def install
    ENV.universal_binary if build.universal?

    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking',
      '--disable-silent-rules',
      "BASE64_BIN=#{Formula['coreutils'].opt_bin/'gbase64'}"
    ]
    args << '--enable-libgdbm-compat' if build.with? 'libgdbm-compat'
    args << '--disable-nls' if build.without? 'nls'

    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end # install

  test do
    for_archs bin/'gdbmtool' do |_, cmd|
      system *cmd, '--norc', '--newdb', 'test', 'store', '1', '2', ';', 'quit'
      assert File.exists?('test')
      assert_match /2/, pipe_output("#{cmd * ' '} --norc test", "fetch 1\nquit\n")
    end
  end # test
end # Gdbm
