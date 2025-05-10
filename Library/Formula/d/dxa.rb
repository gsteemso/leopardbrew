class Dxa < Formula
  desc '6502 cross disassembler'
  homepage 'http://www.floodgap.com/retrotech/xa/'
  url 'http://www.floodgap.com/retrotech/xa/dists/dxa-0.1.5.tar.gz'
  sha256 '8e40ed77816581f9ad95acac2ed69a2fb2ac7850e433d19cd684193a45826799'

  depends_on 'xa'

  patch :DATA

  def install
    system 'make', 'test'
    bin.install 'dxa'
    man1.install 'dxa.1'
  end

  test do
    (testpath/'foo.o65').write [0, 0, 0x20, 0xd2, 0xff].pack 'C*'
    false
    code = `#{bin}/dxa --routine 0000 foo.o65`
    expected = <<-_.undent
      l3 = $3
      \t.word $0000
      \t* = $0000

      l0\tjsr $ffd2
    _
    assert_equal code, expected
  end
end

__END__
--- old/options.h	2019-01-31 19:07:05.000000000 -0800
+++ new/options.h	2024-08-08 17:02:15.000000000 -0700
@@ -39,7 +39,7 @@
 
 /************** USER DEFINED SETTINGS ... you may change these **************/
 
-/* #define LONG_OPTIONS	*//* turn on if you want them -- needs getopt_long() */
+#define LONG_OPTIONS	/* turn on if you want them -- needs getopt_long() */
 
 /******************* WHITE HATS ONLY BELOW THIS POINT !! ********************/
 
--- old/main.c	2022-03-24 23:12:34.000000000 -0700
+++ new/main.c	2024-08-08 17:39:22.000000000 -0700
@@ -29,9 +29,6 @@
 #include <string.h>
 #ifdef __GNUC__
 #include <unistd.h>
-#endif
-#ifdef LONG_OPTIONS
-#include <getopt.h>
 #endif /* __GNUC__ */
 #include "proto.h"
 #include "options.h"
@@ -58,6 +55,7 @@
   extern int optind;
 
 #ifdef LONG_OPTIONS
+#include <getopt.h>
   static struct option cmd_options [] = {
     { "datablock", 1, 0, 'b' }, /* an address range to be marked
                                    as a data block */
