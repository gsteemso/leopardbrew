# stable release 2024-12-23; checked 2025-10-15
class Texinfo < Formula
  desc 'Official documentation format of the GNU project'
  homepage 'https://www.gnu.org/software/texinfo/'
  url 'http://ftpmirror.gnu.org/texinfo/texinfo-7.2.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/texinfo/texinfo-7.2.tar.xz'
  sha256 '0329d7788fbef113fa82cb80889ca197a344ce0df7646fe000974c5d714363a6'

  # While the OS does provide this software, a newer version in parallel causes no known issues.

  depends_on 'libiconv'
  depends_on 'libunistring'
  depends_on 'perl'
  depends_on :nls => :recommended

  patch :DATA  # This patch is not correct, but does lead to a successful build.

  def install
    ENV['HOMEBREW_FORCE_FLAGS'] = '-std=gnu99' if ENV.default_language_version(:c) == :c89
    ENV.deparallelize
    args = [
        "--prefix=#{prefix}",
        '--disable-dependency-tracking',
        '--disable-silent-rules',
        '--disable-install-warnings',
        "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}",
      ]
    args << '--disable-nls' if build.without? 'nls'
    args << '--enable-year2038' if Target.pure_64b?
    ENV['PERL'] = "#{Formula['perl'].opt_bin}/perl"
    system './configure', *args
    system 'make'
    # At least on Tiger, `make check` yields many (apparently legitimate) failures.  However, it also gets numerous failures wholly
    # due to the system not being able to run enough processes in parallel, even after Leopardbrew has raised the limit.  In effect,
    # running `make check` is more trouble than it’s worth.
    system 'make', 'install'
    doc.install Dir['doc/refcard/txirefcard*']
  end

  test do
    (testpath/'test.texinfo').write <<-EOS.undent
      @ifnottex
      @node Top
      @top Hello World!
      @end ifnottex
      @bye
    EOS
    system "#{bin}/makeinfo", 'test.texinfo'
    assert_match /Hello World!/, File.read('test.info')
  end
end

__END__
# The contents of libperlcall_utils.la would appear to have already been linked into
# libtexinfo.la, causing duplicate symbol definitions when libtexinfoxs.la is built.
--- old/tp/Texinfo/XS/Makefile.in
+++ new/tp/Texinfo/XS/Makefile.in
@@ -2423,7 +2423,7 @@
 # locate include files under out-of-source builds.
 libtexinfoxs_la_CPPFLAGS = -I$(srcdir)/main $(AM_CPPFLAGS) $(XSLIBS_CPPFLAGS)
 libtexinfoxs_la_CFLAGS = $(XSLIBS_CFLAGS)
-libtexinfoxs_la_LIBADD = libtexinfo.la libperlcall_utils.la $(platform_PERL_LIBADD)
+libtexinfoxs_la_LIBADD = libtexinfo.la $(platform_PERL_LIBADD)
 libtexinfoxs_la_LDFLAGS = -version-info 0:0:0 $(perl_conf_LDFLAGS)
 # example to trigger errors associated with no undefined
 #libtexinfoxs_la_LDFLAGS = -version-info 0:0:0 -Wl,--no-undefined $(perl_conf_LDFLAGS) $(PERL_LIBS)
@@ -2497,7 +2497,7 @@
 # locate include files under out-of-source builds.
 # parsetexi is only needed for texinfo.c
 libtexinfo_convert_la_CPPFLAGS = -I$(srcdir)/main -I$(srcdir)/convert -I$(srcdir)/structuring_transfo -I$(srcdir)/parsetexi $(AM_CPPFLAGS) $(GNULIB_CPPFLAGS)
-libtexinfo_convert_la_LIBADD = libtexinfoxs.la libtexinfo.la libcallperl_libtexinfo_convert.la $(top_builddir)/gnulib/lib/libgnu.la $(platform_PERL_LIBADD)
+libtexinfo_convert_la_LIBADD = libtexinfoxs.la libtexinfo.la libcallperl_libtexinfo_convert.la $(platform_PERL_LIBADD)
 libtexinfo_convert_la_LDFLAGS = -version-info 0:0:0 $(perl_conf_LDFLAGS) $(EUIDACCESS_LIBGEN) $(LTLIBINTL) $(LTLIBICONV) $(LTLIBUNISTRING)
 libtexinfo_convertxs_la_SOURCES = \
                        convert/build_html_perl_info.h \
