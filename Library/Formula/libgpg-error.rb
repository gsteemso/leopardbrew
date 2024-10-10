class LibgpgError < Formula
  desc 'Common error values for all GnuPG components'
  homepage 'https://www.gnupg.org/software/libgpg-error/index.html'
  url 'https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.50.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.50.tar.bz2'
  sha256 '69405349e0a633e444a28c5b35ce8f14484684518a508dc48a089992fe93e20a'

  option :universal

  depends_on 'pkg-config' => :build
  depends_on 'gettext'
  depends_on 'readline'

  # patch for Darwin’s unusually‐indirect environment access
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    ENV.append_to_cflags '-D__DARWIN_UNIX03' if MacOS.version == :tiger
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--enable-install-gpg-error-config',
                          '--disable-silent-rules',
                          '--enable-static',
                          '--enable-threads',
                          "--with-readline=#{Formula['readline'].opt_prefix}"
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    ENV['PKG_CONFIG_PATH'] = lib/'pkgconfig'
    system "#{bin}/gpgrt-config", '--libs'
  end
end

__END__
--- old/src/spawn-posix.c	2024-06-19 00:33:41 -0700
+++ new/src/spawn-posix.c	2024-10-02 18:34:07.000000000 -0700
@@ -36,6 +36,7 @@
 # include <signal.h>
 #endif
 #include <unistd.h>
+#include <crt_externs.h>
 #include <fcntl.h>
 
 #include <sys/socket.h>
@@ -318,6 +319,7 @@
 my_exec (const char *pgmname, const char *argv[], gpgrt_spawn_actions_t act)
 {
   int i;
+  char **envp;
 
   /* Assign /dev/null to unused FDs.  */
   for (i = 0; i <= 2; i++)
@@ -342,7 +344,9 @@
   _gpgrt_close_all_fds (3, act->except_fds);
 
   if (act->environ)
-    environ = act->environ;
+    envp = act->environ;
+  else
+    envp = _NSGetEnviron;
 
   if (act->atfork)
     act->atfork (act->atfork_arg);
@@ -351,7 +355,7 @@
   if (pgmname == NULL)
     return 0;
 
-  execv (pgmname, (char *const *)argv);
+  execve (pgmname, (char *const *)argv, (char *const *)envp);
   /* No way to print anything, as we have may have closed all streams. */
   _exit (127);
   return -1;
