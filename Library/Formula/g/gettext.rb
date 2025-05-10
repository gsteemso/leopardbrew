class Gettext < Formula
  desc "GNU internationalization (i18n) and localization (l10n) library"
  homepage "https://www.gnu.org/software/gettext/"
  url "http://ftpmirror.gnu.org/gettext/gettext-0.22.5.tar.lz"
  mirror "https://ftp.gnu.org/gnu/gettext/gettext-0.22.5.tar.lz"
  # Fetching the LZIPped version of this package, rather than the XZ-compressed
  # one, allows {xz} to use NLS (internationalization) without forming a
  # dependency loop.  It’s also much smaller.
  sha256 "caa44aed29c9b4900f1a401d68f6599a328a3744569484dc95f62081e80ad6cb"

  # Neither gettext nor libintl are included with any version of Mac OS!  Why
  # did they think this needed to be keg‐only?

  option :universal
  option 'without-tests', 'Skip the build‐time unit tests (not recommended for a first install)'
  # former option to leave out the examples is not available in `configure`

  enhanced_by 'libiconv'

  # Fix lang-python-* failures when in a traditional French locale.
  # https://git.savannah.gnu.org/gitweb/?p=gettext.git;a=patch;h=3c7e67be7d4dab9df362ab19f4f5fa3b9ca0836b
  # Also, skip the gnulib tests as they have their own set of problems, with
  # nothing to do with what’s being built.
  patch :p0, :DATA

  def install
    ENV.universal_binary if build.universal?
    system "./configure", "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--disable-debug',
                          '--with-included-gettext',
                          '--with-included-libunistring',
                          '--with-included-libxml',
                          '--with-emacs',
                          "--with-lispdir=#{share}/emacs/site-lisp/gettext",
                          '--disable-java',
                          '--disable-csharp',
                          '--without-git', # Don't use VCSes to create these archives
                          '--without-cvs', #
                          '--without-xz'  # avoid a dependency loop
    system 'make'
    ENV.deparallelize do
      bombproof_system 'make', 'check' if build.with? 'tests'
      system 'make', 'install'
    end
  end # install

  def caveats; <<-_.undent
    GNU Gettext and GNU Libiconv are circularly dependent on one another.  The
    `libiconv` formula explicitly depends on this one, which means gettext will
    be brewed for you (if it wasn’t already) when you brew libiconv.  The reverse
    cannot be done at the same time because of the circular dependency.  To ensure
    the full functionality of both packages, you should `brew reinstall gettext`
    after you have brewed libiconv.

    They should be brewed in this order because Mac OS includes an outdated iconv
    that is enough to get by with, but does not include gettext at all.
  _
  end # caveats

  test do
    arch_system "#{bin}/gettext", '--version'
    arch_system "#{bin}/gettext", '--help'
  end # test
end # Gettext

__END__
--- gettext-tools/tests/lang-python-1.orig	2023-09-18 21:10:32.000000000 +0100
+++ gettext-tools/tests/lang-python-1	2023-11-30 23:15:43.000000000 +0000
@@ -3,9 +3,10 @@
 
 # Test of gettext facilities in the Python language.
 
-# Note: This test fails with Python 2.3 ... 2.7 when an UTF-8 locale is present.
+# Note: This test fails with Python 2.3 ... 2.7 when an ISO-8859-1 locale is
+# present.
 # It looks like a bug in Python's gettext.py. This here is a quick workaround:
-UTF8_LOCALE_UNSUPPORTED=yes
+ISO8859_LOCALE_UNSUPPORTED=yes
 
 cat <<\EOF > prog1.py
 import gettext
@@ -82,16 +83,16 @@
 
 : ${LOCALE_FR=fr_FR}
 : ${LOCALE_FR_UTF8=fr_FR.UTF-8}
-if test $LOCALE_FR != none; then
-  prepare_locale_ fr $LOCALE_FR
-  LANGUAGE= LC_ALL=$LOCALE_FR python prog1.py > prog.out || Exit 1
-  ${DIFF} prog.ok prog.out || Exit 1
+if test $LOCALE_FR_UTF8 != none; then
+  prepare_locale_ fr $LOCALE_FR_UTF8
+  LANGUAGE= LC_ALL=$LOCALE_FR_UTF8 python prog1.py > prog.out || Exit 1
+  ${DIFF} prog.oku prog.out || Exit 1
 fi
-if test -z "$UTF8_LOCALE_UNSUPPORTED"; then
-  if test $LOCALE_FR_UTF8 != none; then
-    prepare_locale_ fr $LOCALE_FR_UTF8
-    LANGUAGE= LC_ALL=$LOCALE_FR_UTF8 python prog1.py > prog.out || Exit 1
-    ${DIFF} prog.oku prog.out || Exit 1
+if test -z "$ISO8859_LOCALE_UNSUPPORTED"; then
+  if test $LOCALE_FR != none; then
+    prepare_locale_ fr $LOCALE_FR
+    LANGUAGE= LC_ALL=$LOCALE_FR python prog1.py > prog.out || Exit 1
+    ${DIFF} prog.ok prog.out || Exit 1
   fi
   if test $LOCALE_FR = none && test $LOCALE_FR_UTF8 = none; then
     if test -f /usr/bin/localedef; then
@@ -102,11 +103,11 @@
     Exit 77
   fi
 else
-  if test $LOCALE_FR = none; then
+  if test $LOCALE_FR_UTF8 = none; then
     if test -f /usr/bin/localedef; then
-      echo "Skipping test: no traditional french locale is installed"
+      echo "Skipping test: no french Unicode locale is installed"
     else
-      echo "Skipping test: no traditional french locale is supported"
+      echo "Skipping test: no french Unicode locale is supported"
     fi
     Exit 77
   fi
--- gettext-tools/tests/lang-python-2.orig	2023-09-18 21:10:32.000000000 +0100
+++ gettext-tools/tests/lang-python-2	2023-11-30 23:15:43.000000000 +0000
@@ -4,9 +4,10 @@
 # Test of gettext facilities (including plural handling) in the Python
 # language.
 
-# Note: This test fails with Python 2.3 ... 2.7 when an UTF-8 locale is present.
+# Note: This test fails with Python 2.3 ... 2.7 when an ISO-8859-1 locale is
+# present.
 # It looks like a bug in Python's gettext.py. This here is a quick workaround:
-UTF8_LOCALE_UNSUPPORTED=yes
+ISO8859_LOCALE_UNSUPPORTED=yes
 
 cat <<\EOF > prog2.py
 import sys
@@ -103,16 +104,16 @@
 
 : ${LOCALE_FR=fr_FR}
 : ${LOCALE_FR_UTF8=fr_FR.UTF-8}
-if test $LOCALE_FR != none; then
-  prepare_locale_ fr $LOCALE_FR
-  LANGUAGE= LC_ALL=$LOCALE_FR python prog2.py 2 > prog.out || Exit 1
-  ${DIFF} prog.ok prog.out || Exit 1
+if test $LOCALE_FR_UTF8 != none; then
+  prepare_locale_ fr $LOCALE_FR_UTF8
+  LANGUAGE= LC_ALL=$LOCALE_FR_UTF8 python prog2.py 2 > prog.out || Exit 1
+  ${DIFF} prog.oku prog.out || Exit 1
 fi
-if test -z "$UTF8_LOCALE_UNSUPPORTED"; then
-  if test $LOCALE_FR_UTF8 != none; then
-    prepare_locale_ fr $LOCALE_FR_UTF8
-    LANGUAGE= LC_ALL=$LOCALE_FR_UTF8 python prog2.py 2 > prog.out || Exit 1
-    ${DIFF} prog.oku prog.out || Exit 1
+if test -z "$ISO8859_LOCALE_UNSUPPORTED"; then
+  if test $LOCALE_FR != none; then
+    prepare_locale_ fr $LOCALE_FR
+    LANGUAGE= LC_ALL=$LOCALE_FR python prog2.py 2 > prog.out || Exit 1
+    ${DIFF} prog.ok prog.out || Exit 1
   fi
   if test $LOCALE_FR = none && test $LOCALE_FR_UTF8 = none; then
     if test -f /usr/bin/localedef; then
@@ -123,11 +124,11 @@
     Exit 77
   fi
 else
-  if test $LOCALE_FR = none; then
+  if test $LOCALE_FR_UTF8 = none; then
     if test -f /usr/bin/localedef; then
-      echo "Skipping test: no traditional french locale is installed"
+      echo "Skipping test: no french Unicode locale is installed"
     else
-      echo "Skipping test: no traditional french locale is supported"
+      echo "Skipping test: no french Unicode locale is supported"
     fi
     Exit 77
   fi
--- gettext-tools/Makefile.in.orig	2024-04-09 14:16:44.000000000 +0000
+++ gettext-tools/Makefile.in	2024-04-09 14:17:28.000000000 +0000
@@ -3416,7 +3416,7 @@
 top_srcdir = @top_srcdir@
 AUTOMAKE_OPTIONS = 1.5 gnu no-dependencies
 ACLOCAL_AMFLAGS = -I m4 -I ../gettext-runtime/m4 -I ../m4 -I gnulib-m4 -I libgrep/gnulib-m4 -I libgettextpo/gnulib-m4
-SUBDIRS = gnulib-lib libgrep src libgettextpo po its projects styles emacs misc man m4 tests system-tests gnulib-tests examples doc
+SUBDIRS = gnulib-lib libgrep src libgettextpo po its projects styles emacs misc man m4 tests system-tests examples doc
 
 # Allow users to use "gnulib-tool --update".
 
