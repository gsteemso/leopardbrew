# stable release 2025-03-21; checked 2026-03-12.
class Libidn < Formula
  desc 'International domain name library, old version'
  homepage 'https://www.gnu.org/software/libidn/'
  url 'https://ftpmirror.gnu.org/libidn/libidn-1.43.tar.gz'
  mirror 'https://ftp.gnu.org/gnu/libidn/libidn-1.43.tar.gz'
  sha256 'bdc662c12d041b2539d0e638f3a6e741130cdb33a644ef3496963a443482d164'

  option :universal

  depends_on 'pkg-config' => :build
  depends_on :nls_iconv   => :recommended

  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --disable-csharp
      --with-lispdir=#{share}/emacs/site-lisp/#{name}
    ]
    if build.without? 'nls' then args << '--disable-nls'; else
      args << "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}" << "--with-libintl-prefix=#{Formula['gettext'].opt_prefix}"
    end
    args << '--enable-year2038' if Target._64b?
    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end # install

  test do
    ENV['CHARSET'] = 'UTF-8'
    arch_system "#{bin}/idn", 'räksmörgås.se', 'blåbærgrød.no'
  end
end # Libidn

__END__
# As “doc/libidn.info” is a distributed file, we should only be regenerating it if it’s been removed.
--- old/doc/Makefile.in
+++ new/doc/Makefile.in
@@ -1786,7 +1786,7 @@
 	-rm -rf .libs _libs
 
 .texi.info:
-	$(AM_V_MAKEINFO)restore=: && backupdir="$(am__leading_dot)am$$$$" && \
+	if ! ( test -f $@ ); then $(AM_V_MAKEINFO)restore=: && backupdir="$(am__leading_dot)am$$$$" && \
 	am__cwd=`pwd` && $(am__cd) $(srcdir) && \
#`
 	rm -rf $$backupdir && mkdir $$backupdir && \
 	if ($(MAKEINFO) --version) >/dev/null 2>&1; then \
@@ -1805,7 +1805,7 @@
 	  $(am__cd) $(srcdir) && \
 	  $$restore $$backupdir/* `echo "./$@" | sed 's|[^/]*$$||'`; \
 	fi; \
-	rm -rf $$backupdir; exit $$rc
+	rm -rf $$backupdir; exit $$rc; fi
 
 .texi.dvi:
 	$(AM_V_TEXI2DVI)TEXINPUTS="$(am__TEXINFO_TEX_DIR)$(PATH_SEPARATOR)$$TEXINPUTS" \
