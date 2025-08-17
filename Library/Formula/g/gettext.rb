# stable release 2025-07-19; checked 2025-08-01
class Gettext < Formula
  desc 'GNU internationalization (i18n) and localization (l10n) library'
  homepage 'https://www.gnu.org/software/gettext/'
  url 'http://ftpmirror.gnu.org/gettext/gettext-0.26.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/gettext/gettext-0.26.tar.lz'
  # Fetching the LZIPped version of this package, rather than the XZ-compressed
  # one, allows {xz} to use NLS (internationalization) without forming a
  # dependency loop.  It’s also much smaller.
  sha256 'a0151088dad8942374dc038e461b228352581defd7055e79297f156268b8d508'

  # Neither gettext nor libintl are included with any version of Mac OS!  Why
  # did the Homebrew and Tigerbrew teams think this needed to be keg‐only?

  option :universal
  # former option to leave out the examples is no longer available in `configure`

  enhanced_by 'libiconv'

  patch :DATA  # What each series of patches does is explained in a comment preceding it.

  def install
    ENV.universal_binary if build.universal?
    args = [
        "--prefix=#{prefix}",
        '--disable-debug',
        '--disable-dependency-tracking',
        '--disable-silent-rules',
        '--with-included-gettext',
        '--with-included-libunistring',
        '--with-included-libxml',
        "--with-lispdir=#{share}/emacs/site-lisp/gettext",
        '--without-git', # Don't use a VCS to create the infrastructure archive.
        '--without-xz'   # Avoid a dependency loop.
      ]
    args << "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}" if enhanced_by? 'libiconv'
    args << '--enable-year2038' if ENV.building_pure_64_bit?
    system './configure', *args
    system 'make'
    # `make check` can no longer be disentangled from Gnulib.  Trying to run the tests is now
    # futile on older systems.
    system 'make', 'install'
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
# Synchronize usage of `gl_long_double_union` between header and implementation.
--- old/gettext-runtime/gnulib-lib/float.in.h
+++ new/gettext-runtime/gnulib-lib/float.in.h
@@ -115,8 +115,7 @@
 
 /* On PowerPC with gcc 15 when using __ibm128 long double, the value of
    LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+# if (defined _ARCH_PPC || defined _POWER) && (defined _AIX || defined __linux__) && (LDBL_MANT_DIG == 106) && defined __GNUC__
 # undef LDBL_MIN_EXP
 # define LDBL_MIN_EXP DBL_MIN_EXP
 # undef LDBL_MIN_10_EXP
--- old/gettext-runtime/intl/gnulib-lib/float.in.h
+++ new/gettext-runtime/intl/gnulib-lib/float.in.h
@@ -115,8 +115,7 @@
 
 /* On PowerPC with gcc 15 when using __ibm128 long double, the value of
    LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+# if (defined _ARCH_PPC || defined _POWER) && (defined _AIX || defined __linux__) && (LDBL_MANT_DIG == 106) && defined __GNUC__
 # undef LDBL_MIN_EXP
 # define LDBL_MIN_EXP DBL_MIN_EXP
 # undef LDBL_MIN_10_EXP
--- old/gettext-runtime/libasprintf/gnulib-lib/float.in.h
+++ new/gettext-runtime/libasprintf/gnulib-lib/float.in.h
@@ -115,8 +115,7 @@
 
 /* On PowerPC with gcc 15 when using __ibm128 long double, the value of
    LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+# if (defined _ARCH_PPC || defined _POWER) && (defined _AIX || defined __linux__) && (LDBL_MANT_DIG == 106) && defined __GNUC__
 # undef LDBL_MIN_EXP
 # define LDBL_MIN_EXP DBL_MIN_EXP
 # undef LDBL_MIN_10_EXP
--- old/gettext-tools/gnulib-lib/float.in.h
+++ new/gettext-tools/gnulib-lib/float.in.h
@@ -115,8 +115,7 @@
 
 /* On PowerPC with gcc 15 when using __ibm128 long double, the value of
    LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+# if (defined _ARCH_PPC || defined _POWER) && (defined _AIX || defined __linux__) && (LDBL_MANT_DIG == 106) && defined __GNUC__
 # undef LDBL_MIN_EXP
 # define LDBL_MIN_EXP DBL_MIN_EXP
 # undef LDBL_MIN_10_EXP
--- old/gettext-tools/libgettextpo/float.in.h
+++ new/gettext-tools/libgettextpo/float.in.h
@@ -115,8 +115,7 @@
 
 /* On PowerPC with gcc 15 when using __ibm128 long double, the value of
    LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+# if (defined _ARCH_PPC || defined _POWER) && (defined _AIX || defined __linux__) && (LDBL_MANT_DIG == 106) && defined __GNUC__
 # undef LDBL_MIN_EXP
 # define LDBL_MIN_EXP DBL_MIN_EXP
 # undef LDBL_MIN_10_EXP
--- old/libtextstyle/lib/float.in.h
+++ new/libtextstyle/lib/float.in.h
@@ -115,8 +115,7 @@
 
 /* On PowerPC with gcc 15 when using __ibm128 long double, the value of
    LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+# if (defined _ARCH_PPC || defined _POWER) && (defined _AIX || defined __linux__) && (LDBL_MANT_DIG == 106) && defined __GNUC__
 # undef LDBL_MIN_EXP
 # define LDBL_MIN_EXP DBL_MIN_EXP
 # undef LDBL_MIN_10_EXP
