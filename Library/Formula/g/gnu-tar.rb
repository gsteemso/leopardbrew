# stable release 2023-07-18; checked 2025-08-05
class GnuTar < Formula
  desc 'GNU version of the tar archiving utility'
  homepage 'https://www.gnu.org/software/tar/'
  url 'http://ftpmirror.gnu.org/tar/tar-1.35.tar.xz'
  mirror 'https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz'
  sha256 '4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16'

  option 'with-default-names', 'Do not prepend “g” to the binary'
  option 'without-libiconv',   'Build without text‐encoding support'

  depends_on :nls       => :recommended
  depends_on 'libiconv' => :recommended

  # These are used by running their executables rather than by linking their libraries, so don’t be
  # alarmed that they do not appear in the linkage lists even when enhancement has been performed.
  enhanced_by 'bzip2'
  enhanced_by 'lzip'
  enhanced_by 'lzop'
  enhanced_by 'xz'  # now includes lzma
  enhanced_by 'zstd'

  # Work around a poorly‐included system header
  patch :DATA if MacOS.version == :tiger

  patch <<'END_OF_PATCH'
--- old/src/Makefile.in
+++ new/src/Makefile.in
@@ -1263,7 +1263,7 @@
 LIBOBJS = @LIBOBJS@
 LIBPMULTITHREAD = @LIBPMULTITHREAD@
 LIBPTHREAD = @LIBPTHREAD@
-LIBS = @LIBS@
+LIBS = $(LIBICONV) $(LIBINTL) @LIBS@
 LIBUNISTRING_UNICASE_H = @LIBUNISTRING_UNICASE_H@
 LIBUNISTRING_UNICTYPE_H = @LIBUNISTRING_UNICTYPE_H@
 LIBUNISTRING_UNINORM_H = @LIBUNISTRING_UNINORM_H@
END_OF_PATCH

  def install
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
    ]
    args << "--with-libiconv-prefix=#{Formula['libiconv'].opt_prefix}" if build.with? 'libiconv'
    args << (build.with?('nls') ? "--with-libintl-prefix=#{Formula['gettext'].opt_prefix}" : '--disable-nls')
    args << '--program-prefix=g' if build.without? 'default-names'
    args << '--disable-year2038' unless ENV.building_pure_64_bit?
    args << "--with-bzip2=#{Formula['bzip2'].opt_bin}/bzip2" if enhanced_by? 'bzip2'
    args << "--with-lzip=#{Formula['lzip'].opt_bin}/lzip" if enhanced_by? 'lzip'
    args << "--with-lzop=#{Formula['lzop'].opt_bin}/lzop" if enhanced_by? 'lzop'
    args << "--with-lzma=#{Formula['xz'].opt_bin}/lzma" << "--with-xz=#{Formula['xz'].opt_bin}/xz" if enhanced_by? 'xz'
    args << "--with-zstd=#{Formula['zstd'].opt_bin}/zstd" if enhanced_by? 'zstd'

    system './configure', *args
    system 'make'
    system 'make', 'install'

    # Symlink the executable into libexec/gnubin as “tar”
    (libexec/'gnubin').install_symlink bin/'gtar' => 'tar' if build.without? 'default-names'
  end

  def caveats
    if build.without? 'default-names' then <<-EOS.undent
      gnu-tar is installed as “gtar”.

      If you really need to use it as “tar”, and don’t want to reïnstall it using the
      “--with-default-names” option, add the “gnubin” directory to your $PATH in your
      shell initialization script:
          PATH="#{opt_libexec}/gnubin:$PATH"
      EOS
    end
  end

  test do
    tar = build.with?('default-names') ? bin/'tar' : bin/'gtar'
    (testpath/'test').write('test')
    system tar, '-czvf', 'test.tar.gz', 'test'
    assert_match /test/, shell_output("#{tar} -xOzf test.tar.gz")
  end
end

__END__
--- old/gnu/stdlib.in.h
+++ new/gnu/stdlib.in.h
@@ -20,6 +20,8 @@
 #endif
 @PRAGMA_COLUMNS@
 
+#include <sys/ucontext.h>
+
 #if defined __need_system_stdlib_h || defined __need_malloc_and_calloc
 /* Special invocation conventions inside some gnulib header files,
    and inside some glibc header files, respectively.  */
--- old/gnu/unistd.in.h
+++ new/gnu/unistd.in.h
@@ -21,6 +21,8 @@
 #endif
 @PRAGMA_COLUMNS@
 
+#include <sys/ucontext.h>
+
 #if @HAVE_UNISTD_H@ && defined _GL_INCLUDING_UNISTD_H
 /* Special invocation convention:
    - On Mac OS X 10.3.9 we have a sequence of nested includes
