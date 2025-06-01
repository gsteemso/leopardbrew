class Libgcrypt < Formula
  desc 'Cryptographic library based on the code from GnuPG'
  homepage 'https://www.gnupg.org/software/libgcrypt/index.html'
  url 'https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.0.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.0.tar.bz2'
  sha256 '09120c9867ce7f2081d6aaa1775386b98c2f2f246135761aae47d81f58685b9c'

  option :universal

  depends_on 'libgpg-error'

  # Availability.h appeared in Leopard
  patch :DATA

  def install
    ENV.universal_binary if build.universal?

    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--disable-asm',
                          '--enable-static'

    # Parallel builds work, but only when run as separate steps
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    for_archs bin/'mpicalc' do |_, cmd|
      system *cmd, '--version'
      system *cmd, '--print-config'
    end
    for_archs bin/'hmac256' do |_, cmd|
      system *cmd, '--version'
      assert_match '0b81e0b2f9f9522b045f0016e03abae259b1dca38713630695be05deb82aea88',
                   shell_output("#{cmd * ' '} 'test key' #{test_fixtures('test.pdf')}")
    end
  end
end

__END__
--- old/random/rndoldlinux.c	2023-11-28 18:04:36 +0000
+++ new/random/rndoldlinux.c	2023-11-28 18:05:45 +0000
@@ -29,7 +29,9 @@
 #include <fcntl.h>
 #include <poll.h>
 #if defined(__APPLE__) && defined(__MACH__)
+#ifdef __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ && __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ >= 1050
 #include <Availability.h>
+#endif
 #ifdef __MAC_10_11
 #include <TargetConditionals.h>
 #if !defined(TARGET_OS_IPHONE) || TARGET_OS_IPHONE == 0
