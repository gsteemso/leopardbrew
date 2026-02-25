# stable release 2025-07-19; checked 2025-12-11
class Gettext < Formula
  desc 'GNU internationalization (i18n) and localization (l10n) library'
  homepage 'https://www.gnu.org/software/gettext/'
  url 'http://ftpmirror.gnu.org/gettext/gettext-0.26.tar.lz'
  mirror 'https://ftp.gnu.org/gnu/gettext/gettext-0.26.tar.lz'
  # Fetching the LZIPped version of this package, rather than the XZ-compressed one, lets {xz} use NLS without forming a dependency
  # loop.  It’s also much smaller.
  sha256 'a0151088dad8942374dc038e461b228352581defd7055e79297f156268b8d508'

  # Neither gettext nor libintl have ever been present on any version of Mac OS.  The Homebrew and Tigerbrew maintainers presumably
  # only made this package keg‐only because Mac OS does include its counterpart, libiconv; but the quantity & magnitude of problems
  # caused by {gettext}’s invisibility to other packages warrant reversing that decision for Leopardbrew.  The brew mechanisms that
  # make keg‐only packages work are meant for library linkage, and can’t make up for the concealment of directly‐executable files –
  # in other words, using gettext requires that its bin/ be visible, which requires that its keg be linked.

  option :universal
  # The unit tests can no longer be disentangled from Gnulib.  Trying to run them is now futile on older systems.
  option 'with-tests', 'Run the build-time unit tests (fails on older systems)'
  # The former option to leave out the examples is no longer available in `configure`.

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
    args << "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}" if active_enhancements.include? 'libiconv'
    args << '--enable-year2038' if Target.pure_64b?
    system './configure', *args
    system 'make'
    system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'
  end # install

  def caveats; <<-_.undent
      GNU Gettext and GNU Libiconv are circularly interdependent.  {libiconv} depends
      explicitly on {gettext} – which means that {gettext} will be brewed for you, if
      it wasn’t already, when you brew {libiconv}.  The reverse can’t be done because
      of the circular dependency.

      TL,DR:  To ensure both packages work correctly, once {libiconv} has been brewed,
      you should `brew reinstall gettext`.

      (They should be brewed in this order because Mac OS includes a bare‐bones iconv,
      but has never included gettext.)
    _
  end # caveats

  test do
    arch_system "#{bin}/gettext", '--version'
    arch_system "#{bin}/gettext", '--help'
  end # test
end # Gettext

__END__
# Fix this header file per Oct. 2025 discussion on the bug-gnulib mailing list:
--- old/gettext-runtime/gnulib-lib/float.in.h
+++ new/gettext-runtime/gnulib-lib/float.in.h
@@ -113,83 +113,32 @@
 # define LDBL_MAX_10_EXP 4932
 #endif
 
-/* On PowerPC with gcc 15 when using __ibm128 long double, the value of
-   LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+/* Current Gnulib lists some compiler failures on PowerPC and concludes that
+   any GCC new enough to define __LDBL_NORM_MAX__ is probably OK. */
+#if (defined _ARCH_PPC && LDBL_MANT_DIG == 106 \
+     && defined __GNUC__ && !defined __LDBL_NORM_MAX__)
 # undef LDBL_MIN_EXP
-# define LDBL_MIN_EXP DBL_MIN_EXP
+# define LDBL_MIN_EXP (-968)
 # undef LDBL_MIN_10_EXP
-# define LDBL_MIN_10_EXP DBL_MIN_10_EXP
+# define LDBL_MIN_10_EXP (-291)
 # undef LDBL_MIN
-# define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
+# define LDBL_MIN 0x1p-969L
+/* Re:  IBM long double format.  See (https://gcc.gnu.org/PR120993).' */
 # undef LDBL_MAX
-/* LDBL_MAX is 2**1024 - 2**918, represented as: { 0x7FEFFFFF, 0xFFFFFFFF,
-                                                   0x7C9FFFFF, 0xFFFFFFFF }.
-
-   Do not write it as a constant expression, as GCC would likely treat
-   that as infinity due to the vagaries of this platform's funky arithmetic.
-   Instead, define it through a reference to an external variable.
-   Like the following, but using a union to avoid type mismatches:
-
-     const double LDBL_MAX[2] = { DBL_MAX, DBL_MAX / 0x1p53 };
-     extern const long double LDBL_MAX;
-
-   The following alternative would not work as well when GCC is optimizing:
-
-     #define LDBL_MAX (*(long double const *) (double[])
-                       { DBL_MAX, DBL_MAX / 0x1p53 })
-
-   The following alternative would require GCC 6 or later:
-
-     #define LDBL_MAX __builtin_pack_longdouble (DBL_MAX, DBL_MAX / 0x1p53)
-
-   Unfortunately none of the alternatives are constant expressions.  */
-# if !GNULIB_defined_long_double_union
-union gl_long_double_union
-  {
-    struct { double hi; double lo; } dd;
-    long double ld;
-  };
-#  define GNULIB_defined_long_double_union 1
-# endif
-extern const union gl_long_double_union gl_LDBL_MAX;
-# define LDBL_MAX (gl_LDBL_MAX.ld)
-# undef LDBL_NORM_MAX
-# define LDBL_NORM_MAX LDBL_MAX
-#endif
-
-/* On IRIX 6.5, with cc, the value of LDBL_MANT_DIG is wrong.
-   On IRIX 6.5, with gcc 4.2, the values of LDBL_MIN_EXP, LDBL_MIN, LDBL_EPSILON
-   are wrong.  */
-#if defined __sgi && (LDBL_MANT_DIG >= 106)
-# undef LDBL_MANT_DIG
-# define LDBL_MANT_DIG 106
-# if defined __GNUC__
-#  undef LDBL_MIN_EXP
-#  define LDBL_MIN_EXP DBL_MIN_EXP
-#  undef LDBL_MIN_10_EXP
-#  define LDBL_MIN_10_EXP DBL_MIN_10_EXP
-#  undef LDBL_MIN
-#  define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
-#  undef LDBL_EPSILON
-#  define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
-# endif
-#endif
+# define LDBL_MAX 0x1.fffffffffffff7ffffffffffff8p+1023L
 
 /* On PowerPC platforms, 'long double' has a double-double representation.
    Up to ISO C 17, this was outside the scope of ISO C because it can represent
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits>, such as
    1.0L + 4.94065645841246544176568792868221e-324L = 1 + 2^-1074; see
    ISO C 17 § 5.2.4.2.2.(3).
    In ISO C 23, wording has been included that makes this 'long double'
    representation compliant; see ISO C 23 § 5.2.5.3.3.(8)-(9).  In this setting,
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits> are
    called "unnormalized".  And since LDBL_EPSILON must be normalized (per
    ISO C 23 § 5.2.5.3.3.(33)), it must be 2^-105.  */
-#if defined __powerpc__ && LDBL_MANT_DIG == 106
 # undef LDBL_EPSILON
-# define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
+# define LDBL_EPSILON 0x1p-105L
 #endif
 
 /* ============================ ISO C11 support ============================ */
--- old/gettext-runtime/intl/gnulib-lib/float.in.h
+++ new/gettext-runtime/intl/gnulib-lib/float.in.h
@@ -113,83 +113,32 @@
 # define LDBL_MAX_10_EXP 4932
 #endif
 
-/* On PowerPC with gcc 15 when using __ibm128 long double, the value of
-   LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+/* Current Gnulib lists some compiler failures on PowerPC and concludes that
+   any GCC new enough to define __LDBL_NORM_MAX__ is probably OK. */
+#if (defined _ARCH_PPC && LDBL_MANT_DIG == 106 \
+     && defined __GNUC__ && !defined __LDBL_NORM_MAX__)
 # undef LDBL_MIN_EXP
-# define LDBL_MIN_EXP DBL_MIN_EXP
+# define LDBL_MIN_EXP (-968)
 # undef LDBL_MIN_10_EXP
-# define LDBL_MIN_10_EXP DBL_MIN_10_EXP
+# define LDBL_MIN_10_EXP (-291)
 # undef LDBL_MIN
-# define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
+# define LDBL_MIN 0x1p-969L
+/* Re:  IBM long double format.  See (https://gcc.gnu.org/PR120993).' */
 # undef LDBL_MAX
-/* LDBL_MAX is 2**1024 - 2**918, represented as: { 0x7FEFFFFF, 0xFFFFFFFF,
-                                                   0x7C9FFFFF, 0xFFFFFFFF }.
-
-   Do not write it as a constant expression, as GCC would likely treat
-   that as infinity due to the vagaries of this platform's funky arithmetic.
-   Instead, define it through a reference to an external variable.
-   Like the following, but using a union to avoid type mismatches:
-
-     const double LDBL_MAX[2] = { DBL_MAX, DBL_MAX / 0x1p53 };
-     extern const long double LDBL_MAX;
-
-   The following alternative would not work as well when GCC is optimizing:
-
-     #define LDBL_MAX (*(long double const *) (double[])
-                       { DBL_MAX, DBL_MAX / 0x1p53 })
-
-   The following alternative would require GCC 6 or later:
-
-     #define LDBL_MAX __builtin_pack_longdouble (DBL_MAX, DBL_MAX / 0x1p53)
-
-   Unfortunately none of the alternatives are constant expressions.  */
-# if !GNULIB_defined_long_double_union
-union gl_long_double_union
-  {
-    struct { double hi; double lo; } dd;
-    long double ld;
-  };
-#  define GNULIB_defined_long_double_union 1
-# endif
-extern const union gl_long_double_union gl_LDBL_MAX;
-# define LDBL_MAX (gl_LDBL_MAX.ld)
-# undef LDBL_NORM_MAX
-# define LDBL_NORM_MAX LDBL_MAX
-#endif
-
-/* On IRIX 6.5, with cc, the value of LDBL_MANT_DIG is wrong.
-   On IRIX 6.5, with gcc 4.2, the values of LDBL_MIN_EXP, LDBL_MIN, LDBL_EPSILON
-   are wrong.  */
-#if defined __sgi && (LDBL_MANT_DIG >= 106)
-# undef LDBL_MANT_DIG
-# define LDBL_MANT_DIG 106
-# if defined __GNUC__
-#  undef LDBL_MIN_EXP
-#  define LDBL_MIN_EXP DBL_MIN_EXP
-#  undef LDBL_MIN_10_EXP
-#  define LDBL_MIN_10_EXP DBL_MIN_10_EXP
-#  undef LDBL_MIN
-#  define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
-#  undef LDBL_EPSILON
-#  define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
-# endif
-#endif
+# define LDBL_MAX 0x1.fffffffffffff7ffffffffffff8p+1023L
 
 /* On PowerPC platforms, 'long double' has a double-double representation.
    Up to ISO C 17, this was outside the scope of ISO C because it can represent
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits>, such as
    1.0L + 4.94065645841246544176568792868221e-324L = 1 + 2^-1074; see
    ISO C 17 § 5.2.4.2.2.(3).
    In ISO C 23, wording has been included that makes this 'long double'
    representation compliant; see ISO C 23 § 5.2.5.3.3.(8)-(9).  In this setting,
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits> are
    called "unnormalized".  And since LDBL_EPSILON must be normalized (per
    ISO C 23 § 5.2.5.3.3.(33)), it must be 2^-105.  */
-#if defined __powerpc__ && LDBL_MANT_DIG == 106
 # undef LDBL_EPSILON
-# define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
+# define LDBL_EPSILON 0x1p-105L
 #endif
 
 /* ============================ ISO C11 support ============================ */
--- old/gettext-runtime/libasprintf/gnulib-lib/float.in.h
+++ new/gettext-runtime/libasprintf/gnulib-lib/float.in.h
@@ -113,83 +113,32 @@
 # define LDBL_MAX_10_EXP 4932
 #endif
 
-/* On PowerPC with gcc 15 when using __ibm128 long double, the value of
-   LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+/* Current Gnulib lists some compiler failures on PowerPC and concludes that
+   any GCC new enough to define __LDBL_NORM_MAX__ is probably OK. */
+#if (defined _ARCH_PPC && LDBL_MANT_DIG == 106 \
+     && defined __GNUC__ && !defined __LDBL_NORM_MAX__)
 # undef LDBL_MIN_EXP
-# define LDBL_MIN_EXP DBL_MIN_EXP
+# define LDBL_MIN_EXP (-968)
 # undef LDBL_MIN_10_EXP
-# define LDBL_MIN_10_EXP DBL_MIN_10_EXP
+# define LDBL_MIN_10_EXP (-291)
 # undef LDBL_MIN
-# define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
+# define LDBL_MIN 0x1p-969L
+/* Re:  IBM long double format.  See (https://gcc.gnu.org/PR120993).' */
 # undef LDBL_MAX
-/* LDBL_MAX is 2**1024 - 2**918, represented as: { 0x7FEFFFFF, 0xFFFFFFFF,
-                                                   0x7C9FFFFF, 0xFFFFFFFF }.
-
-   Do not write it as a constant expression, as GCC would likely treat
-   that as infinity due to the vagaries of this platform's funky arithmetic.
-   Instead, define it through a reference to an external variable.
-   Like the following, but using a union to avoid type mismatches:
-
-     const double LDBL_MAX[2] = { DBL_MAX, DBL_MAX / 0x1p53 };
-     extern const long double LDBL_MAX;
-
-   The following alternative would not work as well when GCC is optimizing:
-
-     #define LDBL_MAX (*(long double const *) (double[])
-                       { DBL_MAX, DBL_MAX / 0x1p53 })
-
-   The following alternative would require GCC 6 or later:
-
-     #define LDBL_MAX __builtin_pack_longdouble (DBL_MAX, DBL_MAX / 0x1p53)
-
-   Unfortunately none of the alternatives are constant expressions.  */
-# if !GNULIB_defined_long_double_union
-union gl_long_double_union
-  {
-    struct { double hi; double lo; } dd;
-    long double ld;
-  };
-#  define GNULIB_defined_long_double_union 1
-# endif
-extern const union gl_long_double_union gl_LDBL_MAX;
-# define LDBL_MAX (gl_LDBL_MAX.ld)
-# undef LDBL_NORM_MAX
-# define LDBL_NORM_MAX LDBL_MAX
-#endif
-
-/* On IRIX 6.5, with cc, the value of LDBL_MANT_DIG is wrong.
-   On IRIX 6.5, with gcc 4.2, the values of LDBL_MIN_EXP, LDBL_MIN, LDBL_EPSILON
-   are wrong.  */
-#if defined __sgi && (LDBL_MANT_DIG >= 106)
-# undef LDBL_MANT_DIG
-# define LDBL_MANT_DIG 106
-# if defined __GNUC__
-#  undef LDBL_MIN_EXP
-#  define LDBL_MIN_EXP DBL_MIN_EXP
-#  undef LDBL_MIN_10_EXP
-#  define LDBL_MIN_10_EXP DBL_MIN_10_EXP
-#  undef LDBL_MIN
-#  define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
-#  undef LDBL_EPSILON
-#  define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
-# endif
-#endif
+# define LDBL_MAX 0x1.fffffffffffff7ffffffffffff8p+1023L
 
 /* On PowerPC platforms, 'long double' has a double-double representation.
    Up to ISO C 17, this was outside the scope of ISO C because it can represent
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits>, such as
    1.0L + 4.94065645841246544176568792868221e-324L = 1 + 2^-1074; see
    ISO C 17 § 5.2.4.2.2.(3).
    In ISO C 23, wording has been included that makes this 'long double'
    representation compliant; see ISO C 23 § 5.2.5.3.3.(8)-(9).  In this setting,
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits> are
    called "unnormalized".  And since LDBL_EPSILON must be normalized (per
    ISO C 23 § 5.2.5.3.3.(33)), it must be 2^-105.  */
-#if defined __powerpc__ && LDBL_MANT_DIG == 106
 # undef LDBL_EPSILON
-# define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
+# define LDBL_EPSILON 0x1p-105L
 #endif
 
 /* ============================ ISO C11 support ============================ */
--- old/gettext-tools/gnulib-lib/float.in.h
+++ new/gettext-tools/gnulib-lib/float.in.h
@@ -113,83 +113,32 @@
 # define LDBL_MAX_10_EXP 4932
 #endif
 
-/* On PowerPC with gcc 15 when using __ibm128 long double, the value of
-   LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+/* Current Gnulib lists some compiler failures on PowerPC and concludes that
+   any GCC new enough to define __LDBL_NORM_MAX__ is probably OK. */
+#if (defined _ARCH_PPC && LDBL_MANT_DIG == 106 \
+     && defined __GNUC__ && !defined __LDBL_NORM_MAX__)
 # undef LDBL_MIN_EXP
-# define LDBL_MIN_EXP DBL_MIN_EXP
+# define LDBL_MIN_EXP (-968)
 # undef LDBL_MIN_10_EXP
-# define LDBL_MIN_10_EXP DBL_MIN_10_EXP
+# define LDBL_MIN_10_EXP (-291)
 # undef LDBL_MIN
-# define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
+# define LDBL_MIN 0x1p-969L
+/* Re:  IBM long double format.  See (https://gcc.gnu.org/PR120993).' */
 # undef LDBL_MAX
-/* LDBL_MAX is 2**1024 - 2**918, represented as: { 0x7FEFFFFF, 0xFFFFFFFF,
-                                                   0x7C9FFFFF, 0xFFFFFFFF }.
-
-   Do not write it as a constant expression, as GCC would likely treat
-   that as infinity due to the vagaries of this platform's funky arithmetic.
-   Instead, define it through a reference to an external variable.
-   Like the following, but using a union to avoid type mismatches:
-
-     const double LDBL_MAX[2] = { DBL_MAX, DBL_MAX / 0x1p53 };
-     extern const long double LDBL_MAX;
-
-   The following alternative would not work as well when GCC is optimizing:
-
-     #define LDBL_MAX (*(long double const *) (double[])
-                       { DBL_MAX, DBL_MAX / 0x1p53 })
-
-   The following alternative would require GCC 6 or later:
-
-     #define LDBL_MAX __builtin_pack_longdouble (DBL_MAX, DBL_MAX / 0x1p53)
-
-   Unfortunately none of the alternatives are constant expressions.  */
-# if !GNULIB_defined_long_double_union
-union gl_long_double_union
-  {
-    struct { double hi; double lo; } dd;
-    long double ld;
-  };
-#  define GNULIB_defined_long_double_union 1
-# endif
-extern const union gl_long_double_union gl_LDBL_MAX;
-# define LDBL_MAX (gl_LDBL_MAX.ld)
-# undef LDBL_NORM_MAX
-# define LDBL_NORM_MAX LDBL_MAX
-#endif
-
-/* On IRIX 6.5, with cc, the value of LDBL_MANT_DIG is wrong.
-   On IRIX 6.5, with gcc 4.2, the values of LDBL_MIN_EXP, LDBL_MIN, LDBL_EPSILON
-   are wrong.  */
-#if defined __sgi && (LDBL_MANT_DIG >= 106)
-# undef LDBL_MANT_DIG
-# define LDBL_MANT_DIG 106
-# if defined __GNUC__
-#  undef LDBL_MIN_EXP
-#  define LDBL_MIN_EXP DBL_MIN_EXP
-#  undef LDBL_MIN_10_EXP
-#  define LDBL_MIN_10_EXP DBL_MIN_10_EXP
-#  undef LDBL_MIN
-#  define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
-#  undef LDBL_EPSILON
-#  define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
-# endif
-#endif
+# define LDBL_MAX 0x1.fffffffffffff7ffffffffffff8p+1023L
 
 /* On PowerPC platforms, 'long double' has a double-double representation.
    Up to ISO C 17, this was outside the scope of ISO C because it can represent
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits>, such as
    1.0L + 4.94065645841246544176568792868221e-324L = 1 + 2^-1074; see
    ISO C 17 § 5.2.4.2.2.(3).
    In ISO C 23, wording has been included that makes this 'long double'
    representation compliant; see ISO C 23 § 5.2.5.3.3.(8)-(9).  In this setting,
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits> are
    called "unnormalized".  And since LDBL_EPSILON must be normalized (per
    ISO C 23 § 5.2.5.3.3.(33)), it must be 2^-105.  */
-#if defined __powerpc__ && LDBL_MANT_DIG == 106
 # undef LDBL_EPSILON
-# define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
+# define LDBL_EPSILON 0x1p-105L
 #endif
 
 /* ============================ ISO C11 support ============================ */
--- old/gettext-tools/libgettextpo/float.in.h
+++ new/gettext-tools/libgettextpo/float.in.h
@@ -113,83 +113,32 @@
 # define LDBL_MAX_10_EXP 4932
 #endif
 
-/* On PowerPC with gcc 15 when using __ibm128 long double, the value of
-   LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+/* Current Gnulib lists some compiler failures on PowerPC and concludes that
+   any GCC new enough to define __LDBL_NORM_MAX__ is probably OK. */
+#if (defined _ARCH_PPC && LDBL_MANT_DIG == 106 \
+     && defined __GNUC__ && !defined __LDBL_NORM_MAX__)
 # undef LDBL_MIN_EXP
-# define LDBL_MIN_EXP DBL_MIN_EXP
+# define LDBL_MIN_EXP (-968)
 # undef LDBL_MIN_10_EXP
-# define LDBL_MIN_10_EXP DBL_MIN_10_EXP
+# define LDBL_MIN_10_EXP (-291)
 # undef LDBL_MIN
-# define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
+# define LDBL_MIN 0x1p-969L
+/* Re:  IBM long double format.  See (https://gcc.gnu.org/PR120993).' */
 # undef LDBL_MAX
-/* LDBL_MAX is 2**1024 - 2**918, represented as: { 0x7FEFFFFF, 0xFFFFFFFF,
-                                                   0x7C9FFFFF, 0xFFFFFFFF }.
-
-   Do not write it as a constant expression, as GCC would likely treat
-   that as infinity due to the vagaries of this platform's funky arithmetic.
-   Instead, define it through a reference to an external variable.
-   Like the following, but using a union to avoid type mismatches:
-
-     const double LDBL_MAX[2] = { DBL_MAX, DBL_MAX / 0x1p53 };
-     extern const long double LDBL_MAX;
-
-   The following alternative would not work as well when GCC is optimizing:
-
-     #define LDBL_MAX (*(long double const *) (double[])
-                       { DBL_MAX, DBL_MAX / 0x1p53 })
-
-   The following alternative would require GCC 6 or later:
-
-     #define LDBL_MAX __builtin_pack_longdouble (DBL_MAX, DBL_MAX / 0x1p53)
-
-   Unfortunately none of the alternatives are constant expressions.  */
-# if !GNULIB_defined_long_double_union
-union gl_long_double_union
-  {
-    struct { double hi; double lo; } dd;
-    long double ld;
-  };
-#  define GNULIB_defined_long_double_union 1
-# endif
-extern const union gl_long_double_union gl_LDBL_MAX;
-# define LDBL_MAX (gl_LDBL_MAX.ld)
-# undef LDBL_NORM_MAX
-# define LDBL_NORM_MAX LDBL_MAX
-#endif
-
-/* On IRIX 6.5, with cc, the value of LDBL_MANT_DIG is wrong.
-   On IRIX 6.5, with gcc 4.2, the values of LDBL_MIN_EXP, LDBL_MIN, LDBL_EPSILON
-   are wrong.  */
-#if defined __sgi && (LDBL_MANT_DIG >= 106)
-# undef LDBL_MANT_DIG
-# define LDBL_MANT_DIG 106
-# if defined __GNUC__
-#  undef LDBL_MIN_EXP
-#  define LDBL_MIN_EXP DBL_MIN_EXP
-#  undef LDBL_MIN_10_EXP
-#  define LDBL_MIN_10_EXP DBL_MIN_10_EXP
-#  undef LDBL_MIN
-#  define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
-#  undef LDBL_EPSILON
-#  define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
-# endif
-#endif
+# define LDBL_MAX 0x1.fffffffffffff7ffffffffffff8p+1023L
 
 /* On PowerPC platforms, 'long double' has a double-double representation.
    Up to ISO C 17, this was outside the scope of ISO C because it can represent
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits>, such as
    1.0L + 4.94065645841246544176568792868221e-324L = 1 + 2^-1074; see
    ISO C 17 § 5.2.4.2.2.(3).
    In ISO C 23, wording has been included that makes this 'long double'
    representation compliant; see ISO C 23 § 5.2.5.3.3.(8)-(9).  In this setting,
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits> are
    called "unnormalized".  And since LDBL_EPSILON must be normalized (per
    ISO C 23 § 5.2.5.3.3.(33)), it must be 2^-105.  */
-#if defined __powerpc__ && LDBL_MANT_DIG == 106
 # undef LDBL_EPSILON
-# define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
+# define LDBL_EPSILON 0x1p-105L
 #endif
 
 /* ============================ ISO C11 support ============================ */
--- old/libtextstyle/lib/float.in.h
+++ new/libtextstyle/lib/float.in.h
@@ -113,83 +113,32 @@
 # define LDBL_MAX_10_EXP 4932
 #endif
 
-/* On PowerPC with gcc 15 when using __ibm128 long double, the value of
-   LDBL_MIN_EXP, LDBL_MIN, LDBL_MAX, and LDBL_NORM_MAX are wrong.  */
-#if ((defined _ARCH_PPC || defined _POWER) && LDBL_MANT_DIG == 106 \
-     && defined __GNUC__)
+/* Current Gnulib lists some compiler failures on PowerPC and concludes that
+   any GCC new enough to define __LDBL_NORM_MAX__ is probably OK. */
+#if (defined _ARCH_PPC && LDBL_MANT_DIG == 106 \
+     && defined __GNUC__ && !defined __LDBL_NORM_MAX__)
 # undef LDBL_MIN_EXP
-# define LDBL_MIN_EXP DBL_MIN_EXP
+# define LDBL_MIN_EXP (-968)
 # undef LDBL_MIN_10_EXP
-# define LDBL_MIN_10_EXP DBL_MIN_10_EXP
+# define LDBL_MIN_10_EXP (-291)
 # undef LDBL_MIN
-# define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
+# define LDBL_MIN 0x1p-969L
+/* Re:  IBM long double format.  See (https://gcc.gnu.org/PR120993).' */
 # undef LDBL_MAX
-/* LDBL_MAX is 2**1024 - 2**918, represented as: { 0x7FEFFFFF, 0xFFFFFFFF,
-                                                   0x7C9FFFFF, 0xFFFFFFFF }.
-
-   Do not write it as a constant expression, as GCC would likely treat
-   that as infinity due to the vagaries of this platform's funky arithmetic.
-   Instead, define it through a reference to an external variable.
-   Like the following, but using a union to avoid type mismatches:
-
-     const double LDBL_MAX[2] = { DBL_MAX, DBL_MAX / 0x1p53 };
-     extern const long double LDBL_MAX;
-
-   The following alternative would not work as well when GCC is optimizing:
-
-     #define LDBL_MAX (*(long double const *) (double[])
-                       { DBL_MAX, DBL_MAX / 0x1p53 })
-
-   The following alternative would require GCC 6 or later:
-
-     #define LDBL_MAX __builtin_pack_longdouble (DBL_MAX, DBL_MAX / 0x1p53)
-
-   Unfortunately none of the alternatives are constant expressions.  */
-# if !GNULIB_defined_long_double_union
-union gl_long_double_union
-  {
-    struct { double hi; double lo; } dd;
-    long double ld;
-  };
-#  define GNULIB_defined_long_double_union 1
-# endif
-extern const union gl_long_double_union gl_LDBL_MAX;
-# define LDBL_MAX (gl_LDBL_MAX.ld)
-# undef LDBL_NORM_MAX
-# define LDBL_NORM_MAX LDBL_MAX
-#endif
-
-/* On IRIX 6.5, with cc, the value of LDBL_MANT_DIG is wrong.
-   On IRIX 6.5, with gcc 4.2, the values of LDBL_MIN_EXP, LDBL_MIN, LDBL_EPSILON
-   are wrong.  */
-#if defined __sgi && (LDBL_MANT_DIG >= 106)
-# undef LDBL_MANT_DIG
-# define LDBL_MANT_DIG 106
-# if defined __GNUC__
-#  undef LDBL_MIN_EXP
-#  define LDBL_MIN_EXP DBL_MIN_EXP
-#  undef LDBL_MIN_10_EXP
-#  define LDBL_MIN_10_EXP DBL_MIN_10_EXP
-#  undef LDBL_MIN
-#  define LDBL_MIN 2.22507385850720138309023271733240406422e-308L /* DBL_MIN = 2^-1022 */
-#  undef LDBL_EPSILON
-#  define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
-# endif
-#endif
+# define LDBL_MAX 0x1.fffffffffffff7ffffffffffff8p+1023L
 
 /* On PowerPC platforms, 'long double' has a double-double representation.
    Up to ISO C 17, this was outside the scope of ISO C because it can represent
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits>, such as
    1.0L + 4.94065645841246544176568792868221e-324L = 1 + 2^-1074; see
    ISO C 17 § 5.2.4.2.2.(3).
    In ISO C 23, wording has been included that makes this 'long double'
    representation compliant; see ISO C 23 § 5.2.5.3.3.(8)-(9).  In this setting,
    numbers with mantissas of the form 1.<52 bits><many zeroes><52 bits> are
    called "unnormalized".  And since LDBL_EPSILON must be normalized (per
    ISO C 23 § 5.2.5.3.3.(33)), it must be 2^-105.  */
-#if defined __powerpc__ && LDBL_MANT_DIG == 106
 # undef LDBL_EPSILON
-# define LDBL_EPSILON 2.46519032881566189191165176650870696773e-32L /* 2^-105 */
+# define LDBL_EPSILON 0x1p-105L
 #endif
 
 /* ============================ ISO C11 support ============================ */
