# stable release 2024-12-15; checked 2025-08-01
class Libiconv < Formula
  desc 'Conversion library'
  homepage 'https://www.gnu.org/software/libiconv/'
  url 'http://ftpmirror.gnu.org/libiconv/libiconv-1.18.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz'
  sha256 '3b08f5f4f9b4eb82f151a7040bfd6fe6c6fb922efe4b1659c66ea933276965e8'

  keg_only :provided_by_osx

  option :universal

  depends_on 'autoconf' => :build
  depends_on 'automake' => :build
  depends_on 'gettext'

  # Add definitions for “utf8mac”.
  patch do
    url 'https://raw.githubusercontent.com/Homebrew/patches/9be2793af/libiconv/patch-utf8mac.diff'
    sha256 'e8128732f22f63b5c656659786d2cf76f1450008f36bcf541285268c66cabeab'
  end
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    ENV.deparallelize
    system './configure', "--prefix=#{prefix}",
                          '--disable-debug',
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-extra-encodings',
                          '--enable-static',
                          "--docdir=#{doc}"
    system 'make', '-f', 'Makefile.devel', "CFLAGS=#{ENV.cflags}", "CC=#{ENV.cc}"
    system 'make', 'check'
    system 'make', 'install'
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
    arch_system bin/'iconv', '--help'
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
