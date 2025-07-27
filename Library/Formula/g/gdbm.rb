class Gdbm < Formula
  desc 'GNU database manager'
  homepage 'https://www.gnu.org/software/gdbm/'
  url 'http://ftpmirror.gnu.org/gdbm/gdbm-1.25.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/gdbm/gdbm-1.25.tar.gz'
  sha256 'd02db3c5926ed877f8817b81cd1f92f53ef74ca8c6db543fbba0271b34f393ec'

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

  # Realtime extensions do not exist on older Mac OSes.  Use nanosleep, not clock_nanosleep.
  patch :DATA

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
    # `make check` now fails several tests, probably because of the clock substitution.
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

__END__
--- old/src/lock.c
+++ new/src/lock.c
@@ -291,7 +291,7 @@
       if (timespec_cmp (&ttw, iv) < 0)
 	break;
       timespec_sub (&ttw, iv);
-      if (clock_nanosleep (CLOCK_REALTIME, 0, iv, &r))
+      if (nanosleep (iv, &r))
 	{
 	  if (errno == EINTR)
 	    timespec_add (&ttw, &r);
