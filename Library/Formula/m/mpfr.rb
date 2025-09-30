# Stable release 2025-03-20; checked 2025-08-12
class Mpfr < Formula
  desc 'C library for multiple-precision floating-point computations'
  homepage 'https://www.mpfr.org/'
  url 'https://www.mpfr.org/mpfr-4.2.2/mpfr-4.2.2.tar.xz'
  mirror 'https://ftpmirror.gnu.org/mpfr/mpfr-4.2.2.tar.xz'
  sha256 'b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01'

  option :universal

  depends_on 'gmp'

  patch :DATA  # see inline comments for explanations

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <gmp.h>
      #include <mpfr.h>

      int main()
      {
        mpfr_t x;
        mpfr_init(x);
        mpfr_clear(x);
        return 0;
      }
    EOS
    system ENV.cc, 'test.c', "-L#{HOMEBREW_PREFIX}/lib", '-lgmp', '-lmpfr', '-o', 'test'
    arch_system './test'
  end
end

__END__
# The test for universal compilation always assigns ambiguous endianness, regardless of the facts
# of the matter.
--- old/configure
+++ new/configure
@@ -15584,25 +15584,27 @@
 
 	# Check for potential -arch flags.  It is not universal unless
 	# there are at least two -arch flags with different values.
+	# Even then, endianness is only ambiguous if the values represent
+	# architectures with differing endianness.
-	ac_arch=
 	ac_prev=
+	ac_arch_be= ; ac_arch_el=
 	for ac_word in $CC $CFLAGS $CPPFLAGS $LDFLAGS; do
-	 if test -n "$ac_prev"; then
-	   case $ac_word in
-	     i?86 | x86_64 | ppc | ppc64)
-	       if test -z "$ac_arch" || test "$ac_arch" = "$ac_word"; then
-		 ac_arch=$ac_word
-	       else
-		 ac_cv_c_bigendian=universal
-		 break
-	       fi
-	       ;;
-	   esac
-	   ac_prev=
-	 elif test "x$ac_word" = "x-arch"; then
-	   ac_prev=arch
-	 fi
-       done
+	  if test "x$ac_word" = "x-arch"; then ac_prev=arch
+	  elif test -n "$ac_prev"; then
+	    case $ac_word in
+	      ppc*) ac_arch_be=true;;
+	      *)    ac_arch_el=true;;
+	    esac
+	    ac_prev=
+	  fi
+	done
+	if test -n "$ac_arch_be"; then
+	  if test -n "$ac_arch_el"; then ac_cv_c_bigendian=universal
+	  else ac_cv_c_bigendian=yes
+	  fi
+	elif test -n "$ac_arch_el"; then ac_cv_c_bigendian=no
+	else ac_cv_c_bigendian=unknown
+	fi
 fi
 rm -f core conftest.err conftest.$ac_objext conftest.beam conftest.$ac_ext
     if test $ac_cv_c_bigendian = unknown; then
# “-no-install” is added to LDFLAGS for a reason invalid on Windows or Darwin targets, leading to
# vast numbers of spurious warnings.
--- old/tests/Makefile.in
+++ new/tests/Makefile.in
@@ -1868,7 +1868,7 @@
 #   https://debbugs.gnu.org/cgi/bugreport.cgi?bug=9728
 #   https://debbugs.gnu.org/cgi/bugreport.cgi?bug=18662
 #
-AM_LDFLAGS = -no-install -L$(top_builddir)/src/.libs
+AM_LDFLAGS = -L$(top_builddir)/src/.libs
 all: all-am
 
 .SUFFIXES:
