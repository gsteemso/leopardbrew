class Npth < Formula
  desc 'nPth – new GNU portable threads library'
  homepage 'https://www.gnupg.org/software/npth/index.html'
  url 'https://www.gnupg.org/ftp/gcrypt/npth/npth-1.7.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/npth/npth-1.7.tar.bz2'
  sha256 '8589f56937b75ce33b28d312fccbf302b3b71ec3f3945fde6aaa74027914ad05'

  option :universal

  # POSIX semaphores have never been fully implemented on Mac OS, but the upstream workaround
  # for it uses Grand Central Dispatch and thus only works on Snow Leopard or newer
  patch :DATA if MacOS.version < :snow_leopard

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-install-npth-config',
                          '--enable-static'
    ENV['HOMEBREW_FORCE_FLAGS'] = \
      '-F/System/Library/Frameworks/CoreServices -F/System/Library/Frameworks/CoreServices.framework/Frameworks'
    system 'make', 'install'
  end

  test do
    arch_system bin/'npth-config', '--version'
  end
end

__END__
--- old/src/npth.c	2024-02-05 03:09:26 -0800
+++ new/src/npth.c	2024-10-03 18:02:25 -0700
@@ -29,42 +29,45 @@
 #include <pthread.h>
 #include <fcntl.h>
 #include <sys/stat.h>
-#ifdef HAVE_LIB_DISPATCH
-# include <dispatch/dispatch.h>
-typedef dispatch_semaphore_t sem_t;
-
-/* This glue code is for macOS which does not have full implementation
-   of POSIX semaphore.  On macOS, using semaphore in Grand Central
-   Dispatch library is better than using the partial implementation of
-   POSIX semaphore where sem_init doesn't work well.
- */
+/* This glue code is for versions of Mac OS predating Grand Central Dispatch. */
+#include <CoreServices/CoreServices.h>
+#include <CarbonCore/Multiprocessing.h>
+typedef int sem_t;
 
+/* Note that the MultiProcessing Services API tracks semaphores by ID number, not by address. */
 static int
 sem_init (sem_t *sem, int is_shared, unsigned int value)
 {
+  OSStatus result;
   (void)is_shared;
-  if ((*sem = dispatch_semaphore_create (value)) == NULL)
-    return -1;
-  else
+  result = MPCreateSemaphore ((MPSemaphoreCount)UINT_MAX, (MPSemaphoreCount)value, (MPSemaphoreID *)sem);
+  if (result == noErr)
     return 0;
+  else
+    return -1;
 }
 
 static int
 sem_post (sem_t *sem)
 {
-  dispatch_semaphore_signal (*sem);
-  return 0;
+  OSStatus result;
+  result = MPSignalSemaphore ((MPSemaphoreID) *sem);
+  if (result == noErr)
+    return 0;
+  else
+    return -1;
 }
 
 static int
 sem_wait (sem_t *sem)
 {
-  dispatch_semaphore_wait (*sem, DISPATCH_TIME_FOREVER);
-  return 0;
+  OSStatus result;
+  result = MPWaitOnSemaphore ((MPSemaphoreID) *sem, kDurationForever);
+  if (result == noErr)
+    return 0;
+  else
+    return -1;
 }
-#else
-# include <semaphore.h>
-#endif
 #ifdef HAVE_UNISTD_H
 # include <unistd.h>
 #endif
