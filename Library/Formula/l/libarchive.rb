class Libarchive < Formula
  desc 'Multi-format archive and compression library'
  homepage 'http://www.libarchive.org'
  url 'https://www.libarchive.org/downloads/libarchive-3.7.7.tar.xz'
  sha256 '879acd83c3399c7caaee73fe5f7418e06087ab2aaf40af3e99b9e29beb29faee'

  option :universal
  option 'without-tests', 'Skip the build‐time unit tests'

  depends_on 'bzip2'
  depends_on 'lz4'
  depends_on 'nettle'
  depends_on 'xz'
  depends_on 'zlib'
  depends_on 'zstd'

  keg_only :provided_by_osx

  # ACLs are not working at present; when they are, there’s an oversight where
  # ACL_SYNCHRONIZE is tested for, but then not conditionalized accordingly.
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--disable-acl',
                          '--without-expat',
                          '--with-nettle',
                          '--without-xml2',
                          'ac_cv_header_sys_queue_h=no' # Use its up‐to‐date copy to obtain STAILQ_FOREACH
    system 'make'
    begin
      safe_system 'make', 'check'
    rescue ErrorDuringExecution
      opoo 'Some of the unit tests did not complete successfully.',
        'This is not unusual.  If you ran Leopardbrew in “verbose” mode, the fraction of',
        'tests which failed will be visible in the text above; only you can say whether',
        'the pass rate shown there counts as “good enough”.'
    end if build.with? 'tests'
    system 'make', 'install'
  end # install

  test do
    (testpath/'test').write('test')
    for_archs bin/'bsdtar' do |_, cmd|
      system *cmd, "#{bin}/bsdtar", '-czvf', 'test.tar.gz', 'test'
      result = assert_match /test/, Utils.popen_read(*cmd, "#{bin}/bsdtar", '-xOzf', 'test.tar.gz')
      rm 'test.tar.gz'
      result
    end
  end # test
end # Libarchive

__END__
--- old/configure
+++ new/configure
@@ -18819,44 +18819,6 @@
 printf "%s\n" "#define SIZEOF_INT $ac_cv_sizeof_int" >>confdefs.h
 
 
-{ printf "%s\n" "$as_me:${as_lineno-$LINENO}: checking size of long" >&5
-printf %s "checking size of long... " >&6; }
-if test ${ac_cv_sizeof_long+y}
-then :
-  printf %s "(cached) " >&6
-else $as_nop
-  for ac_size in 4 8 1 2 16  ; do # List sizes in rough order of prevalence.
-  cat confdefs.h - <<_ACEOF >conftest.$ac_ext
-/* end confdefs.h.  */
-
-#include <sys/types.h>
-
-
-int
-main (void)
-{
-switch (0) case 0: case (sizeof (long) == $ac_size):;
-  ;
-  return 0;
-}
-_ACEOF
-if ac_fn_c_try_compile "$LINENO"
-then :
-  ac_cv_sizeof_long=$ac_size
-fi
-rm -f core conftest.err conftest.$ac_objext conftest.beam conftest.$ac_ext
-  if test x$ac_cv_sizeof_long != x ; then break; fi
-done
-
-fi
-
-if test x$ac_cv_sizeof_long = x ; then
-  as_fn_error $? "cannot determine a size for long" "$LINENO" 5
-fi
-{ printf "%s\n" "$as_me:${as_lineno-$LINENO}: result: $ac_cv_sizeof_long" >&5
-printf "%s\n" "$ac_cv_sizeof_long" >&6; }
-
-printf "%s\n" "#define SIZEOF_LONG $ac_cv_sizeof_long" >>confdefs.h
 
 
 
--- old/tar/test/test_option_acls.c
+++ new/tar/test/test_option_acls.c
@@ -26,7 +26,9 @@
     ACL_READ_SECURITY,
     ACL_WRITE_SECURITY,
     ACL_CHANGE_OWNER,
+#if HAVE_DECL_ACL_SYNCHRONIZE
     ACL_SYNCHRONIZE
+#endif
 #else /* !ARCHIVE_ACL_DARWIN */
     ACL_EXECUTE,
     ACL_WRITE,
@@ -47,7 +49,9 @@
     ACL_READ_ACL,
     ACL_WRITE_ACL,
     ACL_WRITE_OWNER,
+#if HAVE_DECL_ACL_SYNCHRONIZE
     ACL_SYNCHRONIZE
+#endif
 #endif	/* ARCHIVE_ACL_FREEBSD_NFS4 */
 #endif /* !ARCHIVE_ACL_DARWIN */
 };
