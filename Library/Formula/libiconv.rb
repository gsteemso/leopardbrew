class Libiconv < Formula
  desc "Conversion library"
  homepage "https://www.gnu.org/software/libiconv/"
  url "http://ftpmirror.gnu.org/libiconv/libiconv-1.17.tar.gz"
  mirror "https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz"
  sha256 "8f74213b56238c85a50a5329f77e06198771e70dd9a739779f4c02f65d971313"

  bottle do
    sha256 "533c88e9e63c7f9b98919951d1aae09a0ac385919cb53957b78ee0eb65f615fc" => :tiger_altivec
  end

  keg_only :provided_by_osx

  option :universal

  depends_on 'gettext'

  patch do
    url "https://raw.githubusercontent.com/Homebrew/patches/9be2793af/libiconv/patch-utf8mac.diff"
    sha256 "e8128732f22f63b5c656659786d2cf76f1450008f36bcf541285268c66cabeab"
  end

  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    ENV.deparallelize
    system "./configure", "--prefix=#{prefix}",
                          "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--enable-extra-encodings",
                          "--enable-static",
                          "--docdir=#{doc}"
    system "make", "-f", "Makefile.devel", "CFLAGS=#{ENV.cflags}", "CC=#{ENV.cc}"
    system 'make', 'check'
    system "make", "install"
  end

  def caveats; <<-_.undent
    GNU Libiconv and GNU Gettext are circularly dependent on one another.  This
    formula explicitly depends on the `gettext` formula, which means gettext will
    be brewed for you (if it wasn’t already) when you brew libiconv.  The reverse
    cannot be done at the same time because of the circular dependency.  To ensure
    the full functionality of both packages, you should `brew reinstall gettext`
    after you have brewed libiconv.

    They should be brewed in this order because Mac OS includes an outdated iconv
    that is enough to get by with, but does not include gettext at all.
  _
  end

  test do
    system bin/"iconv", "--help"
  end
end


__END__
diff --git a/lib/flags.h b/lib/flags.h
index d7cda21..4cabcac 100644
--- a/lib/flags.h
+++ b/lib/flags.h
@@ -14,6 +14,7 @@
 
 #define ei_ascii_oflags (0)
 #define ei_utf8_oflags (HAVE_ACCENTS | HAVE_QUOTATION_MARKS | HAVE_HANGUL_JAMO)
+#define ei_utf8mac_oflags (HAVE_ACCENTS | HAVE_QUOTATION_MARKS | HAVE_HANGUL_JAMO)
 #define ei_ucs2_oflags (HAVE_ACCENTS | HAVE_QUOTATION_MARKS | HAVE_HANGUL_JAMO)
 #define ei_ucs2be_oflags (HAVE_ACCENTS | HAVE_QUOTATION_MARKS | HAVE_HANGUL_JAMO)
 #define ei_ucs2le_oflags (HAVE_ACCENTS | HAVE_QUOTATION_MARKS | HAVE_HANGUL_JAMO)
