class Mpfr < Formula
  desc "C library for multiple-precision floating-point computations"
  homepage "https://www.mpfr.org/"
  url "https://www.mpfr.org/mpfr-4.2.1/mpfr-4.2.1.tar.xz"
  mirror "https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
  sha256 "277807353a6726978996945af13e52829e3abd7a9a5b7fb2793894e18f1fcbb2"

  bottle do
    cellar :any
    sha256 "2be468ac995cbad3fa75c17a7fc41b2967c52591434124de10420b823fc95aa6" => :tiger_altivec
  end

  option :universal

  depends_on "gmp"

  # - The test for universal compilation always assigns ambiguous endianness,
  #   regardless of the facts of the matter.
  # - “-no-install” is added to LDFLAGS for a reason invalid on Windows or
  #   Darwin targets, leading to vast numbers of spurious warnings.
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}",
                          "--disable-silent-rules"
    system "make"
    system "make", "check"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
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
    system ENV.cc, "test.c", "-L#{HOMEBREW_PREFIX}/lib", "-lgmp", "-lmpfr", "-o", "test"
    arch_system "./test"
  end
end

__END__
--- old/configure
+++ new/configure
@@ -14598,25 +14598,37 @@
 
 	# Check for potential -arch flags.  It is not universal unless
 	# there are at least two -arch flags with different values.
+	# Even then, endianness is only ambiguous if the values represent
+	# architectures with differing endianness.
-	ac_arch=
 	ac_prev=
+	ac_arch_be=
+	ac_arch_el=
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
+	  if test "x$ac_word" = "x-arch"; then
+	    ac_prev=arch
+	  elif test -n "$ac_prev"; then
+	    case $ac_word in
+	      arm* | *86*)
+		ac_arch_el=true
+		;;
+	      ppc*)
+		ac_arch_be=true
+		;;
+	    esac
+	    ac_prev=
+	  fi
+	done
+       if test -n "$ac_arch_be"; then
+         if test -n "$ac_arch_el"; then
+           ac_cv_c_bigendian=universal
+         else
+           ac_cv_c_bigendian=yes
+         fi
+       elif test -n "$ac_arch_el"; then
+         ac_cv_c_bigendian=no
+       else
+         ac_cv_c_bigendian=unknown
+       fi
 fi
 rm -f core conftest.err conftest.$ac_objext conftest.beam conftest.$ac_ext
     if test $ac_cv_c_bigendian = unknown; then
--- old/tests/Makefile.in
+++ new/tests/Makefile.in
@@ -1859,7 +1859,7 @@
 #   https://debbugs.gnu.org/cgi/bugreport.cgi?bug=9728
 #   https://debbugs.gnu.org/cgi/bugreport.cgi?bug=18662
 #
-AM_LDFLAGS = -no-install -L$(top_builddir)/src/.libs
+AM_LDFLAGS = -L$(top_builddir)/src/.libs
 all: all-am
 
 .SUFFIXES:
