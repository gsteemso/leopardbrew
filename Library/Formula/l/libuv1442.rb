class Libuv1442 < Formula
  desc 'Multi-platform support library with a focus on asynchronous I/O'
  homepage 'https://github.com/libuv/libuv'
  url 'https://dist.libuv.org/dist/v1.44.2/libuv-v1.44.2-dist.tar.gz'
  sha256 '8ff28f6ac0d6d2a31d2eeca36aff3d7806706c7d3f5971f5ee013ddb0bdd2e9e'

  option 'with-docs',  'Build and install documentation (requires Python)'
  option 'with-tests', 'Run the build‐time unit tests (requires Internet connection)'
  option :universal

#  depends_on 'pkg-config' => :build
  if MacOS.version <= '10.6' and build.with?('docs')
    depends_on :python3   => :build
    depends_on LanguageModuleRequirement.new('python3', sphinx) => :build
  end

  # Older GCC can’t handle having “#pragma GCC diagnostic” inside of a function.
  patch <<END_OF_PATCH if [:gcc_4_0, :gcc, :gcc_llvm].include? ENV.compiler
--- old/src/unix/core.c
+++ new/src/unix/core.c
@@ -555,16 +555,13 @@
  */
 int uv__close_nocancel(int fd) {
 #if defined(__APPLE__)
-#pragma GCC diagnostic push
-#pragma GCC diagnostic ignored "-Wdollar-in-identifier-extension"
 #if defined(__LP64__) || TARGET_OS_IPHONE
   extern int close$NOCANCEL(int);
   return close$NOCANCEL(fd);
 #else
   extern int close$NOCANCEL$UNIX2003(int);
   return close$NOCANCEL$UNIX2003(fd);
 #endif
-#pragma GCC diagnostic pop
 #elif defined(__linux__) && defined(__SANITIZE_THREAD__) && defined(__clang__)
   long rc;
   __sanitizer_syscall_pre_close(fd);
END_OF_PATCH

  # Prior to Mac OS 10.6 (Darwin 10), pthread_setname_np() (for setting thread names) did not exist.
  # Prior to Mac OS 10.7 (Darwin 11), POSIX_SPAWN_CLOEXEC_DEFAULT (an attribute which prevents file
  # descriptor leakage during POSIX‐style process spawning) was not yet invented.
  # These patches catch those cases in preprocessing.
  # → src/unix/internal.h, src/unix/darwin-proctitle.c, src/unix/process.c
  # As of Mac OS 10.7 (Darwin 11), support appeared for IP multicast per RFC 3678.  These patches
  # define symbols and add availability tests.
  # → src/unix/udp.c, test/test-udp-multicast-join.c, test/test-udp-multicast-join6.c
  # Reference to file birthtimes was not possible until 64‐bit inodes were defined.  These patches
  # add preprocessor guards around such references.
  # → src/unix/fs.c, test/test-fs.c
  # Mac OS 10.5 has a buggy boot‐time record in 64‐bit mode; the sysctl call to retrieve it returns
  # a 32‐bit value instead of a 64‐bit one.  This patch adds a corrective action that is applied if
  # the value returned is implausibly large, presuming it due to placement in the wrong half of the
  # space allotted.
  # → src/unix/darwin.c
  patch :DATA

  def install
    ENV.universal_binary if build.universal?

#    ENV.append 'HOMEBREW_FORCE_FLAGS', '-mpim-altivec' if CPU.powerpc? and MacOS.version < '10.5'

    if build.with? 'docs'
      ENV.prepend_create_path 'PYTHONPATH', buildpath/'sphinx/lib/python3/site-packages'
      ENV.prepend_path 'PATH', buildpath/'sphinx/bin'
      # This isn't yet handled by the make install process sadly.
      cd 'docs' do
        system 'make', 'man'
        system 'make', 'singlehtml'
        man1.install 'build/man/libuv.1'
        doc.install Dir['build/singlehtml/*']
      end
    end

    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
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
--- old/src/unix/internal.h
+++ new/src/unix/internal.h
@@ -59,6 +59,7 @@
 #endif /* _AIX */
 
 #if defined(__APPLE__) && !TARGET_OS_IPHONE
+# include <Availability.h>
 # include <AvailabilityMacros.h>
 #endif
 
--- old/src/unix/darwin-proctitle.c
+++ new/src/unix/darwin-proctitle.c
@@ -177,7 +177,9 @@
     goto out;
   }
 
+# if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
   uv__pthread_setname_np(title);  /* Don't care if it fails. */
+# endif
   err = 0;
 
 out:
--- old/src/unix/process.c
+++ new/src/unix/process.c
@@ -51,6 +51,25 @@
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
@@ -387,7 +407,7 @@
 #endif
 
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
 typedef struct uv__posix_spawn_fncs_tag {
   struct {
     int (*addchdir_np)(const posix_spawn_file_actions_t *, const char *);
@@ -839,7 +859,7 @@
   int exec_errorno;
   ssize_t r;
 
-#if defined(__APPLE__)
+#if defined(__APPLE__) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
   uv_once(&posix_spawn_init_once, uv__spawn_init_posix_spawn);
 
   /* Special child process spawn case for macOS Big Sur (11.0) onwards
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
+    !(defined(__APPLE__) && __MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
 static int uv__udp_set_source_membership4(uv_udp_t* handle,
                                           const struct sockaddr_in* multicast_addr,
                                           const char* interface_addr,
@@ -1131,7 +1150,8 @@
     !defined(__ANDROID__) &&                                        \
     !defined(__DragonFly__) &&                                      \
     !defined(__QNX__) &&                                            \
-    !defined(__GNU__)
+    !defined(__GNU__) &&                                            \
+    !(defined(__APPLE__) && __MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
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
+    (defined(__APPLE__) && __MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
+  RETURN_SKIP("This platform does not support multicasting as a server.");
+#endif
   int r;
   struct sockaddr_in addr;
 
--- old/test/test-udp-multicast-join6.c
+++ new/test/test-udp-multicast-join6.c
@@ -169,6 +169,15 @@
 
 
 TEST_IMPL(udp_multicast_join6) {
+#if defined(__OpenBSD__)   ||                                      \
+    defined(__NetBSD__)    ||                                      \
+    defined(__ANDROID__)   ||                                      \
+    defined(__DragonFly__) ||                                      \
+    defined(__QNX__)       ||                                      \
+    defined(__GNU__)       ||                                      \
+    (defined(__APPLE__) && __MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
+  RETURN_SKIP("This platform does not support multicasting as a server.");
+#endif
   int r;
   struct sockaddr_in6 addr;
 
--- old/src/unix/fs.c
+++ new/src/unix/fs.c
@@ -1061,7 +1061,7 @@
 
     return -1;
   }
-#elif defined(__APPLE__)           || \
+#elif (defined(__APPLE__) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1050) || \
       defined(__DragonFly__)       || \
       defined(__FreeBSD__)         || \
       defined(__FreeBSD_kernel__)
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
--- old/src/unix/darwin.c
+++ new/src/unix/darwin.c
@@ -177,7 +177,9 @@
   if (sysctl(which, ARRAY_SIZE(which), &info, &size, NULL, 0))
     return UV__ERR(errno);
 
+#if defined(__LP64__)
+  if (info.tv_sec > 1 << 30)
+    info.tv_sec >>= 32;
+#endif
+
   now = time(NULL);
   *uptime = now - info.tv_sec;
 
