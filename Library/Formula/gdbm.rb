class Gdbm < Formula
  desc 'GNU database manager'
  homepage 'https://www.gnu.org/software/gdbm/'
  url 'http://ftpmirror.gnu.org/gdbm/gdbm-1.24.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/gdbm/gdbm-1.24.tar.gz'
  sha256 '695e9827fdf763513f133910bc7e6cfdb9187943a4fec943e57449723d2b8dbf'

  option :universal
  option 'without-libgdbm-compat', 'Omit the libgdbm_compat library, which provides old‐style dbm/ndbm interfaces'

  depends_on 'coreutils'
  depends_on 'readline'

  depends_on 'autoconf' => :build
  depends_on 'automake' => :build
  depends_on 'm4'       => :build

  keg_only :provided_by_osx  # technically untrue if built without libgdbm-compat

  # A libintl dependency was missing from the test Makefile.  Patch from upstream.
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

    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    pipe_output("#{bin}/gdbmtool --norc --newdb test", "store 1 2\nquit\n")
    assert File.exist?("test")
    assert_match /2/, pipe_output("#{bin}/gdbmtool --norc test", "fetch 1\nquit\n")
  end
end

__END__
--- a/tests/Makefile.am
+++ b/tests/Makefile.am
@@ -142,6 +142,6 @@ dtdump_LDADD = ../src/libgdbm.la ../compat/libgdbm_compat.la
 dtfetch_LDADD = ../src/libgdbm.la ../compat/libgdbm_compat.la
 dtdel_LDADD = ../src/libgdbm.la ../compat/libgdbm_compat.la
 d_creat_ce_LDADD = ../src/libgdbm.la ../compat/libgdbm_compat.la
-t_wordwrap_LDADD = ../tools/libgdbmapp.a
+t_wordwrap_LDADD = ../tools/libgdbmapp.a @LTLIBINTL@
 
 SUBDIRS = gdbmtool
 
