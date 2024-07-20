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

  keg_only :provided_by_osx  # technically untrue if built without libgdbm-compat

  # the “t_wordwrap” test has a ridiculous oversight where they omitted one of its dependency
  # libraries from the Makefile, causing it to not build
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
--- old/tests/Makefile.in	2024-07-15 22:08:03.000000000 -0700
+++ new/tests/Makefile.in	2024-07-15 22:09:43.000000000 -0700
@@ -214,7 +214,7 @@
 t_dumpload_DEPENDENCIES = ../src/libgdbm.la
 t_wordwrap_SOURCES = t_wordwrap.c
 t_wordwrap_OBJECTS = t_wordwrap.$(OBJEXT)
-t_wordwrap_DEPENDENCIES = ../tools/libgdbmapp.a
+t_wordwrap_DEPENDENCIES = ../src/libgdbm.la ../tools/libgdbmapp.a
 AM_V_P = $(am__v_P_@AM_V@)
 am__v_P_ = $(am__v_P_@AM_DEFAULT_V@)
 am__v_P_0 = false
@@ -550,7 +550,7 @@
 dtfetch_LDADD = ../src/libgdbm.la ../compat/libgdbm_compat.la
 dtdel_LDADD = ../src/libgdbm.la ../compat/libgdbm_compat.la
 d_creat_ce_LDADD = ../src/libgdbm.la ../compat/libgdbm_compat.la
-t_wordwrap_LDADD = ../tools/libgdbmapp.a
+t_wordwrap_LDADD = ../src/libgdbm.la ../tools/libgdbmapp.a
 SUBDIRS = gdbmtool
 all: all-recursive
 
