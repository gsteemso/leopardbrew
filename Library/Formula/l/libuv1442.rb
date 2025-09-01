class Libuv1442 < Formula
  desc 'Multi-platform support library with a focus on asynchronous I/O (last version to not require C11)'
  homepage 'https://github.com/libuv/libuv'
  url 'https://dist.libuv.org/dist/v1.44.2/libuv-v1.44.2-dist.tar.gz'
  sha256 '8ff28f6ac0d6d2a31d2eeca36aff3d7806706c7d3f5971f5ee013ddb0bdd2e9e'

  conflicts_with 'libuv', 'libuv1510', :because => 'these are all the same package, and not keg‐only'

  option :universal
  option 'with-docs',  'Build and install documentation (requires Python 3)'
  option 'with-tests', 'Run the build‐time unit tests (requires Internet connection)'

  if MacOS.version <= :snow_leopard and build.with?('docs')
    depends_on :python3   => :build
    depends_on LanguageModuleRequirement.new(:python3, 'sphinx') => :build
  end

  patch <<'END_OF_PATCH' if [:gcc_4_0, :gcc, :gcc_llvm].include? ENV.compiler
# Older GCC can’t handle having “#pragma GCC diagnostic” inside of a function.
--- old/src/unix/core.c
+++ new/src/unix/core.c
@@ -555,16 +555,16 @@
  */
 int uv__close_nocancel(int fd) {
 #if defined(__APPLE__)
-#pragma GCC diagnostic push
-#pragma GCC diagnostic ignored "-Wdollar-in-identifier-extension"
+
+
 #if defined(__LP64__) || TARGET_OS_IPHONE
   extern int close$NOCANCEL(int);
   return close$NOCANCEL(fd);
 #else
   extern int close$NOCANCEL$UNIX2003(int);
   return close$NOCANCEL$UNIX2003(fd);
 #endif
-#pragma GCC diagnostic pop
+
 #elif defined(__linux__) && defined(__SANITIZE_THREAD__) && defined(__clang__)
   long rc;
   __sanitizer_syscall_pre_close(fd);
END_OF_PATCH

  patch :DATA  # See the embedded comments preceding each sub‐patchset.

  patch <<'END_OF_PATCH' if MacOS.version < :leopard
# There is no libutil on systems prior to Leopard.
--- old/Makefile.in
+++ new/Makefile.in
@@ -255,7 +255,7 @@
 @DARWIN_TRUE@                    src/unix/proctitle.c \
 @DARWIN_TRUE@                    src/unix/random-getentropy.c
 
-@DARWIN_TRUE@am__append_31 = -lutil
+#am__append_31 = -lutil
 @DRAGONFLY_TRUE@am__append_32 = include/uv/bsd.h
 @DRAGONFLY_TRUE@am__append_33 = src/unix/bsd-ifaddrs.c \
 @DRAGONFLY_TRUE@                    src/unix/bsd-proctitle.c \
END_OF_PATCH

  def install
    ENV.universal_binary if build.universal?
    args = %W[
        --prefix=#{prefix}
        --disable-dependency-tracking
        --disable-silent-rules
      ]
    args += '--enable-year2038' if ENV.building_pure_64_bit?
    system './configure', *args
    system 'make'
    system 'make', 'check' if build.with? 'tests'
    system 'make', 'install'

    if build.with? 'docs'
      ENV.prepend_path 'PATH', HOMEBREW_PREFIX/'bin'
      # This isn't yet handled by the make install process sadly.
      cd 'docs' do
        system 'make', 'man'
        system 'make', 'singlehtml'
        man1.install 'build/man/libuv.1'
        doc.install Dir['build/singlehtml/*']
      end
      ENV.remove 'PATH', HOMEBREW_PREFIX/'bin', ':'
    end
  end # install

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
  end # test
end # Libuv1442

__END__
# For whatever reason, configure inserts “-std=gnu89” into $CFLAGS, even though it already inserted
# “-std=gnu99” into $CC.  This was a source of potential errors too obvious and egregious to ignore.
--- old/configure
+++ new/configure
@@ -4973,7 +4973,7 @@
   done
 
 
-  for flag in -std=gnu89; do
+  for flag in ; do
 
   { printf "%s\n" "$as_me:${as_lineno-$LINENO}: checking if $CC supports $flag flag" >&5
 printf %s "checking if $CC supports $flag flag... " >&6; }
# Before Mac OS 10.5 (Darwin 9), there wasn’t any <spawn.h> header.  Before Mac OS 10.6 (Darwin 10),
# pthread_setname_np() (for setting thread names) didn’t yet exist.  Before Mac OS 10.7 (Darwin 11),
# POSIX_SPAWN_CLOEXEC_DEFAULT (which guards against file‐descriptor leakage during POSIXish process
# spawning) was not yet invented.  These patches help to address those cases in preprocessing.
# → src/unix/darwin-proctitle.c, src/unix/process.c
--- old/src/unix/darwin-proctitle.c
+++ new/src/unix/darwin-proctitle.c
@@ -177,7 +177,9 @@
     goto out;
   }
 
+# if MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
   uv__pthread_setname_np(title);  /* Don't care if it fails. */
+# endif
   err = 0;
 
 out:
--- old/src/unix/process.c
+++ new/src/unix/process.c
@@ -36,7 +36,9 @@
 #include <poll.h>
 
 #if defined(__APPLE__)
+# if TARGET_OS_IPHONE || MAC_OS_X_VERSION_MIN_REQUIRED >= 1050
 # include <spawn.h>
+# endif
 # include <paths.h>
 # include <sys/kauth.h>
 # include <sys/types.h>
@@ -51,6 +53,25 @@
 #  define POSIX_SPAWN_SETSID 1024
 # endif
 
+/* Mac OS prior to 10.7 does not define this constant */
+# ifndef POSIX_SPAWN_CLOEXEC_DEFAULT
+#  define POSIX_SPAWN_CLOEXEC_DEFAULT 0x4000
+# endif
+
+# if __DARWIN_C_LEVEL < 200809L
+/* This strnlen() implementation was taken verbatim from GNUlib. */
+/* Find the length of S, but scan at most MAXLEN bytes.
+   If no '\0' terminator is found in MAXLEN bytes, return MAXLEN.  */
+size_t strnlen (const char *s, size_t maxlen) {
+  /* Do not use memchr, because on some platforms memchr has
+     undefined behavior if MAXLEN exceeds the number of bytes in S.  */
+  size_t i;
+  for (i = 0; i < maxlen && s[i]; i++)
+    continue;
+  return i;
+}
+# endif
+
 #else
 extern char **environ;
 #endif
@@ -387,7 +408,7 @@
 #endif
 
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && (TARGET_OS_IPHONE || MAC_OS_X_VERSION_MIN_REQUIRED >= 1070)
 typedef struct uv__posix_spawn_fncs_tag {
   struct {
     int (*addchdir_np)(const posix_spawn_file_actions_t *, const char *);
@@ -839,7 +860,7 @@
   int exec_errorno;
   ssize_t r;
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && (TARGET_OS_IPHONE || MAC_OS_X_VERSION_MIN_REQUIRED >= 1070)
   uv_once(&posix_spawn_init_once, uv__spawn_init_posix_spawn);
 
   /* Special child process spawn case for macOS Big Sur (11.0) onwards
# Mac OS 10.7 (Darwin 11) and later enable IP multicast per RFC 3678.  These patches define symbols
# and add availability tests.
# → src/unix/udp.c, test/test-udp-multicast-join.c, test/test-udp-multicast-join6.c
--- old/src/unix/udp.c
+++ new/src/unix/udp.c
@@ -32,6 +32,24 @@
 #endif
 #include <sys/un.h>
 
+#if defined(__APPLE__) && !defined(IP_ADD_SOURCE_MEMBERSHIP)
+# define IP_ADD_SOURCE_MEMBERSHIP  70
+# define IP_DROP_SOURCE_MEMBERSHIP 71
+# define MCAST_JOIN_SOURCE_GROUP   82
+# define MCAST_LEAVE_SOURCE_GROUP  83
+# pragma pack(4)
+struct ip_mreq_source {
+    struct in_addr imr_multiaddr;
+    struct in_addr imr_sourceaddr;
+    struct in_addr imr_interface;
+};
+struct group_source_req {
+                   uint32_t gsr_interface;
+    struct sockaddr_storage gsr_group;
+    struct sockaddr_storage gsr_source;
+};
+#endif
+
 #if defined(IPV6_JOIN_GROUP) && !defined(IPV6_ADD_MEMBERSHIP)
 # define IPV6_ADD_MEMBERSHIP IPV6_JOIN_GROUP
 #endif
@@ -938,7 +956,8 @@
     !defined(__ANDROID__) &&                                        \
     !defined(__DragonFly__) &&                                      \
     !defined(__QNX__) &&                                            \
-    !defined(__GNU__)
+    !defined(__GNU__) &&                                            \
+    !(defined(__APPLE__) && defined(MAC_OS_X_VERSION_MIN_REQUIRED) && MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
 static int uv__udp_set_source_membership4(uv_udp_t* handle,
                                           const struct sockaddr_in* multicast_addr,
                                           const char* interface_addr,
@@ -1131,7 +1150,8 @@
     !defined(__ANDROID__) &&                                        \
     !defined(__DragonFly__) &&                                      \
     !defined(__QNX__) &&                                            \
-    !defined(__GNU__)
+    !defined(__GNU__) &&                                            \
+    !(defined(__APPLE__) && defined(MAC_OS_X_VERSION_MIN_REQUIRED) && MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
   int err;
   union uv__sockaddr mcast_addr;
   union uv__sockaddr src_addr;
--- old/test/test-udp-multicast-join.c
+++ new/test/test-udp-multicast-join.c
@@ -138,6 +138,15 @@
 
 
 TEST_IMPL(udp_multicast_join) {
+#if defined(__OpenBSD__)   ||                                      \
+    defined(__NetBSD__)    ||                                      \
+    defined(__ANDROID__)   ||                                      \
+    defined(__DragonFly__) ||                                      \
+    defined(__QNX__)       ||                                      \
+    defined(__GNU__)       ||                                      \
+    (defined(__APPLE__) && defined(MAC_OS_X_VERSION_MIN_REQUIRED) && MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
+  RETURN_SKIP("This platform does not support multicasting as a server.");
+#endif
   int r;
   struct sockaddr_in addr;
 
--- old/test/test-udp-multicast-join6.c
+++ new/test/test-udp-multicast-join6.c
@@ -167,6 +167,15 @@
 
 
 TEST_IMPL(udp_multicast_join6) {
+#if defined(__OpenBSD__)   ||                                      \
+    defined(__NetBSD__)    ||                                      \
+    defined(__ANDROID__)   ||                                      \
+    defined(__DragonFly__) ||                                      \
+    defined(__QNX__)       ||                                      \
+    defined(__GNU__)       ||                                      \
+    (defined(__APPLE__) && defined(MAC_OS_X_VERSION_MIN_REQUIRED) && MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
+  RETURN_SKIP("This platform does not support multicasting as a server.");
+#endif
   int r;
   struct sockaddr_in6 addr;
 
# Reference to file birthtimes was impossible before 64‐bit inodes were defined.  These patches add
# preprocessor guards around such references. Also, lutimes(3) was not defined on Mac OS 10.4.
# → src/unix/fs.c, test/test-fs.c
--- old/src/unix/fs.c
+++ new/src/unix/fs.c
@@ -1061,7 +1061,7 @@
 
     return -1;
   }
-#elif defined(__APPLE__)           || \
+#elif (defined(__APPLE__) && (TARGET_OS_IPHONE || MAC_OS_X_VERSION_MIN_REQUIRED >= 1050)) || \
       defined(__DragonFly__)       || \
       defined(__FreeBSD__)         || \
       defined(__FreeBSD_kernel__)
@@ -1187,7 +1187,7 @@
   ts[0] = uv__fs_to_timespec(req->atime);
   ts[1] = uv__fs_to_timespec(req->mtime);
   return utimensat(AT_FDCWD, req->path, ts, AT_SYMLINK_NOFOLLOW);
-#elif defined(__APPLE__)          ||                                          \
+#elif (defined(__APPLE__) && (TARGET_OS_IPHONE || MAC_OS_X_VERSION_MIN_REQUIRED >= 1050)) || \
       defined(__DragonFly__)      ||                                          \
       defined(__FreeBSD__)        ||                                          \
       defined(__FreeBSD_kernel__) ||                                          \
@@ -1448,8 +1448,10 @@
   dst->st_mtim.tv_nsec = src->st_mtimespec.tv_nsec;
   dst->st_ctim.tv_sec = src->st_ctimespec.tv_sec;
   dst->st_ctim.tv_nsec = src->st_ctimespec.tv_nsec;
+# if __DARWIN_64_BIT_INO_T
   dst->st_birthtim.tv_sec = src->st_birthtimespec.tv_sec;
   dst->st_birthtim.tv_nsec = src->st_birthtimespec.tv_nsec;
+# endif
   dst->st_flags = src->st_flags;
   dst->st_gen = src->st_gen;
 #elif defined(__ANDROID__)
--- old/test/test-fs.c
+++ new/test/test-fs.c
@@ -1410,7 +1410,7 @@
   ASSERT(0 == uv_fs_fstat(NULL, &req, file, NULL));
   ASSERT(req.result == 0);
   s = req.ptr;
-# if defined(__APPLE__)
+# if defined(__APPLE__) && __DARWIN_64_BIT_INO_T
   ASSERT(s->st_birthtim.tv_sec == t.st_birthtimespec.tv_sec);
   ASSERT(s->st_birthtim.tv_nsec == t.st_birthtimespec.tv_nsec);
 # elif defined(__linux__)
# Mac OS 10.4 is a bit eccentric; its unsetenv(3) does not return a value.  Failing to address this
# function‐signature mismatch causes a fatal build error on that OS.  It is also missing some lines
# from its <unistd.h> header file, one of which is required for the function that assesses possible
# parallelism; an ioctl related to PTY names does not yet exist; & no $NOCANCEL version of close(2)
# is implemented yet.
# → src/unix/core.c, src/unix/tty.c
--- old/src/unix/core.c
+++ new/src/unix/core.c
@@ -554,7 +554,7 @@
  * by making the system call directly. Musl libc is unaffected.
  */
 int uv__close_nocancel(int fd) {
-#if defined(__APPLE__)
+#if defined(__APPLE__) && (TARGET_OS_IPHONE || MAC_OS_X_VERSION_MIN_REQUIRED >= 1050)
 
 
 #if defined(__LP64__) || TARGET_OS_IPHONE
@@ -1362,8 +1362,12 @@
   if (name == NULL)
     return UV_EINVAL;
 
+#if defined(MAC_OS_X_VERSION_MIN_REQUIRED) && MAC_OS_X_VERSION_MIN_REQUIRED < 1050
+  unsetenv(name);
+#else
   if (unsetenv(name) != 0)
     return UV__ERR(errno);
+#endif
 
   return 0;
 }
@@ -1658,6 +1662,9 @@
 #else  /* __linux__ */
   long rc;
 
+#if defined(__APPLE__) && !defined(_SC_NPROCESSORS_ONLN)
+# define _SC_NPROCESSORS_ONLN 58
+#endif
   rc = sysconf(_SC_NPROCESSORS_ONLN);
   if (rc < 1)
     rc = 1;
--- old/src/unix/tty.c
+++ new/src/unix/tty.c
@@ -85,7 +85,7 @@
   int dummy;
 
   result = ioctl(fd, TIOCGPTN, &dummy) != 0;
-#elif defined(__APPLE__)
+#elif defined(__APPLE__) && defined(TIOCPTYGNAME)
   char dummy[256];
 
   result = ioctl(fd, TIOCPTYGNAME, &dummy) != 0;
# Mac OS 10.5 has a buggy boot‐time record in 64‐bit mode; the sysctl call to retrieve it returns a
# 32‐bit value instead of a 64‐bit one.  This patch adds a corrective action that is applied if the
# value returned is implausibly large, presuming it due to placement in the wrong half of the space
# allotted.
--- old/src/unix/darwin.c
+++ new/src/unix/darwin.c
@@ -177,6 +177,11 @@
   if (sysctl(which, ARRAY_SIZE(which), &info, &size, NULL, 0))
     return UV__ERR(errno);
 
+#if defined(__LP64__)
+  if (info.tv_sec > 1 << 40)
+    info.tv_sec >>= 32;
+#endif
+
   now = time(NULL);
   *uptime = now - info.tv_sec;
 
