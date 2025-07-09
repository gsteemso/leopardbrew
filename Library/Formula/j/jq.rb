class Jq < Formula
  desc 'Lightweight and flexible command-line JSON processor'
  homepage 'https://jqlang.org/'
  url 'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-1.5.tar.gz'
  sha256 'c4d2bfec6436341113419debf479d833692cc5cdab7eb0326b5a4d4fbe9f493c'

  bottle do
    cellar :any
    revision 1
    sha256 'd969487931abc27767a3435f5a1b2d06ed61aab0916de187ed894b6137baceee' => :el_capitan
    sha256 '8529bc1edac66bdeec82afe80ce671b9d015b02959fe9f37efd2887fd975faf1' => :yosemite
    sha256 '89a32fb53e7f4330d6db84ba526133228189ea3ba3b15adf7fc743787c8ef645' => :mavericks
    sha256 'd817dec8745f52802b4ac2fbcd2a7a76a647b2000f43ba9a842f59a4363da55d' => :mountain_lion
  end

  option :universal

  # only depends on 'bison' if using maintainer mode
  depends_on 'oniguruma'

  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-maintainer-mode',
                          '--disable-silent-rules'
    system 'make'
    # `make check` fails messily, dying with segfaults when processing inputs above a certain level
    # of complexity.  It doesn’t help that some of the tests absolutely require Valgrind, which was
    # never produced for Power Macs; or that the documentation tests require a great many Ruby gems,
    # none of which are available to Leopardbrew’s internal Ruby installation.
    system 'make', 'install'
  end # install

  test do
    for_archs(bin/'jq') do |_, cmd|
      assert_equal "2\n", pipe_output("#{cmd * ' '} .bar", '{"foo":1, "bar":2}')
    end
  end
end # Jq

__END__
# Allow installing :universal as long as the endianness is consistent.
--- old/configure
+++ new/configure
@@ -18214,25 +18214,37 @@
 
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
+	if test -n "$ac_arch_be"; then
+	  if test -n "$ac_arch_el"; then
+	    ac_cv_c_bigendian=universal
+	  else
+	    ac_cv_c_bigendian=yes
+	  fi
+	elif test -n "$ac_arch_el"; then
+	  ac_cv_c_bigendian=no
+	else
+	  ac_cv_c_bigendian=unknown
+	fi
 fi
 rm -f core conftest.err conftest.$ac_objext conftest.$ac_ext
     if test $ac_cv_c_bigendian = unknown; then
