class Libuv < Formula
  desc 'Multi-platform support library with a focus on asynchronous I/O'
  homepage 'https://github.com/libuv/libuv'
  url 'https://github.com/libuv/libuv/archive/v1.7.4.tar.gz'
  sha256 '5f9625845f509029e44974a67c7e599d11ff9333f8c48a301a098e740cf9ba6c'

  bottle do
    cellar :any
    sha256 '85f20d13e5df5250b6acc30b89032b2d1994ae6c58e654450aa45a4b3858023d' => :el_capitan
    sha256 '601d405156f24be8dfb069a0df726b00f310f99a1e72ccc7083453b8826b636a' => :yosemite
    sha256 'ef03b634cb3eb23aad3e8ff6021a5681d8f37451e0b7365aeca487c946b75a49' => :mavericks
    sha256 '0f5d4b86eb35d5c3477d2c8221b6d8653646aa98d7e5220010f7878692e3ddf7' => :mountain_lion
  end

  option :universal
  option 'with-docs',  'Build and install documentation (requires Python)'
  option 'with-tests', 'Run the build‐time unit tests (requires Internet connection)'

  depends_on 'automake'   => :build
  depends_on 'autoconf'   => :build
  depends_on 'libtool'    => :build
  # During the build process, --gnu is passed to M4, which is only understood by GNU M4 1.4.12 or
  # later.  Apple stock M4 on all releases is forked from GNU version 1.4.6.
  depends_on 'm4'         => :build
  depends_on 'pkg-config' => :build
  depends_on :python      => :build if (build.with? 'docs' and MacOS.version <= :snow_leopard)

  resource 'alabaster' do
    url 'https://pypi.python.org/packages/source/a/alabaster/alabaster-0.7.4.tar.gz'
    sha256 'ce77e2fdbaabaae393ffce2a6252a0a666e3977c6c2fa1c48c4ded0569785951'
  end

  resource 'babel' do
    url 'https://pypi.python.org/packages/source/B/Babel/Babel-1.3.tar.gz'
    sha256 '9f02d0357184de1f093c10012b52e7454a1008be6a5c185ab7a3307aceb1d12e'
  end

  resource 'docutils' do
    url 'https://pypi.python.org/packages/source/d/docutils/docutils-0.12.tar.gz'
    sha256 'c7db717810ab6965f66c8cf0398a98c9d8df982da39b4cd7f162911eb89596fa'
  end

  resource 'pygments' do
    url 'https://pypi.python.org/packages/source/P/Pygments/Pygments-2.0.2.tar.gz'
    sha256 '7320919084e6dac8f4540638a46447a3bd730fca172afc17d2c03eed22cf4f51'
  end

  resource 'jinja2' do
    url 'https://pypi.python.org/packages/source/J/Jinja2/Jinja2-2.7.3.tar.gz'
    sha256 '2e24ac5d004db5714976a04ac0e80c6df6e47e98c354cb2c0d82f8879d4f8fdb'
  end

  resource 'markupsafe' do
    url 'https://pypi.python.org/packages/source/M/MarkupSafe/MarkupSafe-0.23.tar.gz'
    sha256 'a4ec1aff59b95a14b45eb2e23761a0179e98319da5a7eb76b56ea8cdc7b871c3'
  end

  resource 'snowballstemmer' do
    url 'https://pypi.python.org/packages/source/s/snowballstemmer/snowballstemmer-1.2.0.tar.gz'
    sha256 '6d54f350e7a0e48903a4e3b6b2cabd1b43e23765fbc975065402893692954191'
  end

  resource 'six' do
    url 'https://pypi.python.org/packages/source/s/six/six-1.9.0.tar.gz'
    sha256 'e24052411fc4fbd1f672635537c3fc2330d9481b18c0317695b46259512c91d5'
  end

  resource 'pytz' do
    url 'https://pypi.python.org/packages/source/p/pytz/pytz-2015.4.tar.bz2'
    sha256 'a78b484d5472dd8c688f8b3eee18646a25c66ce45b2c26652850f6af9ce52b17'
  end

  resource 'sphinx' do
    url 'https://pypi.python.org/packages/source/S/Sphinx/Sphinx-1.3.1.tar.gz'
    sha256 '1a6e5130c2b42d2de301693c299f78cc4bd3501e78b610c08e45efc70e2b5114'
  end

  resource 'sphinx_rtd_theme' do
    url 'https://pypi.python.org/packages/source/s/sphinx_rtd_theme/sphinx_rtd_theme-0.1.7.tar.gz'
    sha256 '9a490c861f6cf96a0050c29a92d5d1e01eda02ae6f50760ad5c96a327cdf14e8'
  end

  # Only make references to file birthtimes when 64‐bit inodes are available, as file `stat`s did
  # not include them before that; FSEventStreams are not available before Mac OS 10.5; also, ignore
  # CoreServices with its parochial duplicate definitions and archaïc vector syntax.
  patch :DATA if MacOS.version <= :leopard  # adjust this when we learn where the cutoff is

  patch <<'END_OF_PATCH' if MacOS.version < :leopard
# 64-bit inodes are only available from Leopard onwards.
--- old/Makefile.am
+++ new/Makefile.am
@@ -292,7 +292,6 @@
 
 if DARWIN
 include_HEADERS += include/uv-darwin.h
-libuv_la_CFLAGS += -D_DARWIN_USE_64_BIT_INODE=1
 libuv_la_CFLAGS += -D_DARWIN_UNLIMITED_SELECT=1
 libuv_la_SOURCES += src/unix/darwin.c \
                     src/unix/darwin-proctitle.c \
END_OF_PATCH

  def install
    ENV.universal_binary if build.universal?

    ENV.append 'HOMEBREW_FORCE_FLAGS', '-mpim-altivec' if CPU.powerpc? and MacOS.version < :leopard

    if build.with? 'docs'
      ENV.prepend_create_path 'PYTHONPATH', buildpath/'sphinx/lib/python2.7/site-packages'
      resources.each do |r|
        r.stage do
          system 'python', *Language::Python.setup_install_args(buildpath/'sphinx')
        end
      end
      ENV.prepend_path 'PATH', buildpath/'sphinx/bin'
      # This isn't yet handled by the make install process sadly.
      cd 'docs' do
        system 'make', 'man'
        system 'make', 'singlehtml'
        man1.install 'build/man/libuv.1'
        doc.install Dir['build/singlehtml/*']
      end
    end

    args = %W[
        --prefix=#{prefix}
        --disable-dependency-tracking
        --disable-silent-rules
      ]
    args << '--enable-year2038' if Target.pure_64b?
    system './autogen.sh'
    system './configure', *args
    system 'make'
    system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'
  end

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <uv.h>
      #include <stdlib.h>

      int main()
      {
        uv_loop_t* loop = malloc(sizeof *loop);
        uv_loop_init(loop);
        uv_loop_close(loop);
        free(loop);
        return 0;
      }
    EOS

    ENV.universal_binary if build.universal?
    system ENV.cc, 'test.c', '-luv', '-o', 'test'
    arch_system './test'
  end
end

__END__
--- old/src/unix/fs.c
+++ new/src/unix/fs.c
@@ -120,6 +120,14 @@
   while (0)
 
 
+#if defined(__APPLE__) && !defined(MAC_OS_X_VERSION_10_5)
+int sendfile(int fd, int sd, off_t offset, off_t *len, struct sf_hdtr *hdtr, int flags) {
+  errno = EOPNOTSUPP;
+  return -1;
+}
+#endif
+
+
 static ssize_t uv__fs_fdatasync(uv_fs_t* req) {
 #if defined(__linux__) || defined(__sun) || defined(__NetBSD__)
   return fdatasync(req->file);
@@ -708,8 +716,10 @@
   dst->st_mtim.tv_nsec = src->st_mtimespec.tv_nsec;
   dst->st_ctim.tv_sec = src->st_ctimespec.tv_sec;
   dst->st_ctim.tv_nsec = src->st_ctimespec.tv_nsec;
+#if !defined(__APPLE__) || __DARWIN_64_BIT_INO_T
   dst->st_birthtim.tv_sec = src->st_birthtimespec.tv_sec;
   dst->st_birthtim.tv_nsec = src->st_birthtimespec.tv_nsec;
+#endif
   dst->st_flags = src->st_flags;
   dst->st_gen = src->st_gen;
 #elif defined(__ANDROID__)
--- old/src/unix/fsevents.c
+++ new/src/unix/fsevents.c
@@ -21,7 +21,7 @@
 #include "uv.h"
 #include "internal.h"
 
-#if TARGET_OS_IPHONE
+#if TARGET_OS_IPHONE || !defined(MAC_OS_X_VERSION_10_5)
 
 /* iOS (currently) doesn't provide the FSEvents-API (nor CoreServices) */
 
--- old/src/unix/internal.h
+++ new/src/unix/internal.h
@@ -48,9 +48,6 @@
 #include <sys/poll.h>
 #endif /* _AIX */
 
-#if defined(__APPLE__) && !TARGET_OS_IPHONE
-# include <CoreServices/CoreServices.h>
-#endif
 
 #define ACCESS_ONCE(type, var)                                                \
   (*(volatile type*) &(var))
--- old/test/test-fs.c      2024-05-29 22:40:00 -0700
+++ new/test/test-fs.c      2024-05-29 22:40:00 -0700
@@ -1093,8 +1093,10 @@
   ASSERT(s->st_mtim.tv_nsec == t.st_mtimespec.tv_nsec);
   ASSERT(s->st_ctim.tv_sec == t.st_ctimespec.tv_sec);
   ASSERT(s->st_ctim.tv_nsec == t.st_ctimespec.tv_nsec);
+#if !defined(__APPLE__) || __DARWIN_64_BIT_INO_T
   ASSERT(s->st_birthtim.tv_sec == t.st_birthtimespec.tv_sec);
   ASSERT(s->st_birthtim.tv_nsec == t.st_birthtimespec.tv_nsec);
+#endif
   ASSERT(s->st_flags == t.st_flags);
   ASSERT(s->st_gen == t.st_gen);
 #elif defined(_AIX)
@@ -1119,8 +1121,10 @@
       defined(__FreeBSD__)    || \
       defined(__OpenBSD__)    || \
       defined(__NetBSD__)
+#if !defined(__APPLE__) || __DARWIN_64_BIT_INO_T
   ASSERT(s->st_birthtim.tv_sec == t.st_birthtim.tv_sec);
   ASSERT(s->st_birthtim.tv_nsec == t.st_birthtim.tv_nsec);
+#endif
   ASSERT(s->st_flags == t.st_flags);
   ASSERT(s->st_gen == t.st_gen);
 # endif
