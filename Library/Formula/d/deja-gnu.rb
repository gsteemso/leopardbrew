class DejaGnu < Formula
  desc "Framework for testing other programs"
  homepage "https://www.gnu.org/software/dejagnu/"
  url "http://ftpmirror.gnu.org/dejagnu/dejagnu-1.6.3.tar.gz"
  mirror "https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.3.tar.gz"
  sha256 '87daefacd7958b4a69f88c6856dbd1634261963c414079d0c371f589cd66a2e3'

  head do
    url "git://git.sv.gnu.org/dejagnu.git"
    depends_on "automake" => :build
    depends_on "autoconf" => :build
  end

  depends_on 'expect'  # requires at least version 5.0

  patch :DATA if build.stable?

  def install
    ENV.deparallelize # Or fails on Mac Pro
    system "autoreconf", "-iv" if build.head?
    # there is a difficult-to-reproduce build failure on some systems
    # see https://debbugs.gnu.org/cgi/bugreport.cgi?bug=49078
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--mandir=#{man}"
    # deja-gnu is no longer 100% lacking in compiled code,
    # but `make check` still covers everything
    system "make", "check"
    system "make", "install"
  end

  test do
    system "#{bin}/runtest"
  end
end

__END__
--- a/ChangeLog
+++ b/ChangeLog
@@ -1,0 +1,13 @@
+2024-06-19  Jacob Bachmeyer  <jcb@gnu.org>
+
+	PR71624
+
+	* testsuite/lib/libsup.exp (start_expect): Remove "-onlret" from
+	stty_init.  While POSIX defines this option, it is not implemented
+	on Mac OS X 10.5.8 and causes spurious failures on that system.
+	* testsuite/report-card.all/onetest.exp: Likewise.
+
+	* testsuite/report-card.all/passes.exp: While revising stty_init,
+	the lack of a similar setting was noticed in this file.  Ensure
+	that "stty -onlcr" is applied to the Expect ptys.
+
--- a/testsuite/lib/libsup.exp
+++ b/testsuite/lib/libsup.exp
@@ -1,4 +1,4 @@
-# Copyright (C) 1992-2016 Free Software Foundation, Inc.
+# Copyright (C) 1992-2016, 2024 Free Software Foundation, Inc.
 #
 # This file is part of DejaGnu.
 #
@@ -29,7 +29,7 @@ proc start_expect { } {
     # can execute library code without DejaGnu
 
     # Start expect
-    set stty_init { -onlcr -onlret }
+    set stty_init { -onlcr }
     spawn $EXPECT
     expect {
 	-re "expect.*> " {
--- a/testsuite/report-card.all/onetest.exp
+++ b/testsuite/report-card.all/onetest.exp
@@ -1,4 +1,4 @@
-# Copyright (C) 2018 Free Software Foundation, Inc.
+# Copyright (C) 2018, 2024 Free Software Foundation, Inc.
 #
 # This file is part of DejaGnu.
 #
@@ -38,7 +38,7 @@ foreach name $test_names result $test_results {
     close $fd
 }
 
-set stty_init { -onlcr -onlret }
+set stty_init { -onlcr }
 
 spawn /bin/sh -c \
     "cd [testsuite file -object -test onetest]\
--- a/testsuite/report-card.all/passes.exp
+++ b/testsuite/report-card.all/passes.exp
@@ -1,4 +1,4 @@
-# Copyright (C) 2018 Free Software Foundation, Inc.
+# Copyright (C) 2018, 2024 Free Software Foundation, Inc.
 #
 # This file is part of DejaGnu.
 #
@@ -29,6 +29,8 @@ set result_column_map {
 set test_results { PASS FAIL KPASS KFAIL XPASS XFAIL
 		   UNSUPPORTED UNRESOLVED UNTESTED }
 
+set stty_init { -onlcr }
+
 # each entry: { {mode n} { suffix_tag... } { pass... } { { result name }... } }
 array unset tuplemap
 array set tuplemap {
