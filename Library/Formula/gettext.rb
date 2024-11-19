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
  option 'without-tests', 'Skip the self‐testing (not recommended for a first install)'
  # former option to leave out the examples is no longer available in `configure`

  # Fix lang-python-* failures when in a traditional French locale.
  # https://git.savannah.gnu.org/gitweb/?p=gettext.git;a=patch;h=3c7e67be7d4dab9df362ab19f4f5fa3b9ca0836b
  # Also, skip the gnulib tests as they have their own set of problems, with
  # nothing to do with what’s being built.
  patch :p0, :DATA

  def install
    if build.universal?
      ENV.permit_arch_flags if superenv?
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
      the_binaries = %w[
        bin/envsubst
        bin/gettext
        bin/msgattrib
        bin/msgcat
        bin/msgcmp
        bin/msgcomm
        bin/msgconv
        bin/msgen
        bin/msgexec
        bin/msgfilter
        bin/msgfmt
        bin/msggrep
        bin/msginit
        bin/msgmerge
        bin/msgunfmt
        bin/msguniq
        bin/ngettext
        bin/recode-sr-latin
        bin/xgettext
        lib/gettext/cldr-plurals
        lib/gettext/hostname
        lib/gettext/urlget
        lib/libasprintf.0.dylib
        lib/libasprintf.a
        lib/libgettextlib-0.22.5.dylib
        lib/libgettextlib.a
        lib/libgettextpo.0.dylib
        lib/libgettextpo.a
        lib/libgettextsrc-0.22.5.dylib
        lib/libgettextsrc.a
        lib/libintl.8.dylib
        lib/libintl.a
        lib/libtextstyle.0.dylib
        lib/libtextstyle.a
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    args = [
      "--prefix=#{prefix}",
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
      '--without-git', # Don't use VCS systems to create these archives
      '--without-cvs', #
      '--without-xz'
    ]
    lif = Formula['libiconv']
    args << "--with-libiconv-prefix=#{lif.opt_prefix}" if lif.any_version_installed?

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}" if build.universal?

      system "./configure", *args
      system 'make'
      system 'make', 'check' if build.with? 'tests'
      # install doesn't support multiple make jobs
      ENV.deparallelize do
        system 'make', 'install'
      end

      if build.universal?
        system 'make', 'clean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
      end # universal?
    end # each |arch|
    Merge.binaries(prefix, stashdir, archs) if build.universal?
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
  end

  test do
    arch_system "#{bin}/gettext", '--version'
    arch_system "#{bin}/gettext", '--help'
  end # test
end # Gettext

class Merge
  class << self
    include FileUtils

    # The destination is expected to be a Pathname object.
    # The source is just a string.
    def cp_mkp(source, destination)
      if destination.exists?
        if destination.is_directory?
          cp source, destination
        else
          raise "File exists at destination:  #{destination}"
        end # directory?
      else
        mkdir_p destination.parent unless destination.parent.exists?
        cp source, destination
      end # destination exists?
    end # Merge.cp_mkp

    # The keg_prefix and stash_root are expected to be Pathname objects.
    # The list members are just strings.
    def prep(keg_prefix, stash_root, list)
      list.each do |item|
        source = keg_prefix/item
        dest = stash_root/item
        cp_mkp source, dest
      end # each binary
    end # Merge.prep

    # The keg_prefix is expected to be a Pathname object.  The rest are just strings.
    def binaries(keg_prefix, stash_root, archs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dirs = archs.map {|a| "bin-#{a}"}
      arch_dir_list = arch_dirs.join(',')
      Dir["#{stash_root}/{#{arch_dir_list}}/#{s_p}*"].map { |f|
        File.basename(f)
      }.each { |b|
        basename_list << b unless basename_list.count(b) > 0
      }
      basename_list.each do |b|
        spb = s_p + b
        the_arch_dir = arch_dirs.detect { |ad| File.exist?("#{stash_root}/#{ad}/#{spb}") }
        pn = Pathname("#{stash_root}/#{the_arch_dir}/#{spb}")
        if pn.directory?
          binaries(keg_prefix, stash_root, archs, spb)
        else
          arch_files = Dir["#{stash_root}/{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', keg_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, keg_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # each basename |b|
    end # Merge.binaries
  end # << self
end # Merge

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
 
