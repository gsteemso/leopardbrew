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
+++ new/src/npth.c	2024-10-31 11:18:20 -0700
@@ -63,7 +63,41 @@
   return 0;
 }
 #else
-# include <semaphore.h>
+# ifdef __MAC_10_0  /* i.e., if we’re on a Mac at all */
+   /* As noted above, Mac OS only partially implements POSIX semaphores
+      – but Grand Central Dispatch only exists from Mac OS 10.6 onward.
+      This glue code is for versions of Mac OS older than that.
+    */
+#  include <CoreServices/CoreServices.h>
+#  include <CarbonCore/Multiprocessing.h>
+   typedef MPSemaphoreID sem_t;
+
+   static int
+   sem_init (sem_t *sem, int is_shared, unsigned int value)
+   {
+     (void)is_shared;
+     if (MPCreateSemaphore ((MPSemaphoreCount)UINT_MAX, (MPSemaphoreCount)value, sem) == noErr)
+       return 0;
+     else
+       return -1;
+   }
+
+   static int
+   sem_post (sem_t *sem)
+   {
+     MPSignalSemaphore (*sem);
+     return 0;
+   }
+
+   static int
+   sem_wait (sem_t *sem)
+   {
+     MPWaitOnSemaphore (*sem, kDurationForever);
+     return 0;
+   }
+# else
+#  include <semaphore.h>
+# endif
 #endif
 #ifdef HAVE_UNISTD_H
 # include <unistd.h>
