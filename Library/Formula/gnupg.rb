class Gnupg < Formula
  desc 'GNU Privacy Guard:  A free PGP replacement'
  homepage 'https://www.gnupg.org/'
  url 'https://www.gnupg.org/ftp/gcrypt/gnupg/gnupg-2.4.5.tar.bz2'
  mirror 'https://www.mirrorservice.org/sites/www.gnupg.org/ftp/gcrypt/gnupg/gnupg-2.4.5.tar.bz2'
  sha256 'f68f7d75d06cb1635c336d34d844af97436c3f64ea14bcb7c869782f96f44277'

  depends_on 'curl' if MacOS.version <= :mavericks
  depends_on 'gettext'
  # /usr/bin/ld: multiple definitions of symbol _memrchr
  # https://github.com/mistydemeo/tigerbrew/issues/107
  depends_on :ld64
  # will depend on LDAP once there's a formula for it
  depends_on 'libassuan'
  depends_on 'libgcrypt'
  depends_on 'libgpg-error'
  depends_on 'libksba'
  depends_on 'npth'
  depends_on 'ntbtls'
  depends_on 'openssh' # for one of the tests – older systems may have an outdated ssh-add program
  depends_on 'pinentry'
  depends_on 'readline'
  depends_on 'sqlite'
  depends_on 'libusb' => :optional
  depends_on 'gnutls' => :optional

  patch :DATA

  def install
    # It is no longer useful to package GnuPG 1, so GnuPG 2 and gpg-agent no
    # longer need to be separated.
    (var/'run').mkpath
    ENV['gl_cv_absolute_stdint_h'] = "#{MacOS.sdk_path}/usr/include/stdint.h"
    mkdir 'build' do
      args = [
        "--prefix=#{prefix}",
        '--disable-dependency-tracking',
        '--enable-g13',
        '--disable-ldap',  # Leopard stock LDAP predates some of the expected functions
        '--disable-silent-rules',
      ]
      args << '--disable-gnutls' if build.without? 'gnutls'
      system '../configure', *args
      system 'make'
      system 'make', 'check'
      system 'make', 'install'
    end
  end

  test do
    system bin/'gpgconf'
  end
end

__END__
--- old/g10/gpg.h	2023-04-04 01:28:39.000000000 -0700
+++ new/g10/gpg.h	2024-10-04 09:55:48.000000000 -0700
@@ -68,9 +68,6 @@
 struct dirmngr_local_s;
 typedef struct dirmngr_local_s *dirmngr_local_t;
 
-/* Object used to describe a keyblock node.  */
-typedef struct kbnode_struct *KBNODE;   /* Deprecated use kbnode_t. */typedef struct kbnode_struct *kbnode_t;
-
 /* The handle for keydb operations.  */
 typedef struct keydb_handle_s *KEYDB_HANDLE;
 
--- old/g10/keydb.h	2024-03-07 05:17:49 -0800
+++ new/g10/keydb.h	2024-10-04 12:43:11 -0700
@@ -24,6 +24,7 @@
 
 #include "../common/types.h"
 #include "../common/util.h"
+#include "keyring.h"
 #include "packet.h"
 
 /* What qualifies as a certification (key-signature in contrast to a
--- old/g10/keydb-private.h	2023-04-04 01:28:39 -0700
+++ new/g10/keydb-private.h	2024-10-04 09:55:38 -0700
@@ -23,13 +23,9 @@
 
 #include <assuan.h>
 #include "../common/membuf.h"
-
-
-/* Ugly forward declarations.  */
-struct keyring_handle;
-typedef struct keyring_handle *KEYRING_HANDLE;
-struct keybox_handle;
-typedef struct keybox_handle *KEYBOX_HANDLE;
+#include "gpg.h"
+#include "keyring.h"
+#include "../kbx/keybox.h"
 
 
 /* This is for keydb.c and only used in non-keyboxd mode. */
--- old/g10/keyring.h	2023-04-04 01:28:39 -0700
+++ new/g10/keyring.h	2024-10-04 11:06:21 -0700
@@ -22,6 +22,10 @@
 
 #include "../common/userids.h"
 
+/* Object used to describe a keyblock node.  */
+typedef struct kbnode_struct *KBNODE;   /* Deprecated use kbnode_t. */
+typedef struct kbnode_struct *kbnode_t;
+
 typedef struct keyring_handle *KEYRING_HANDLE;
 
 int keyring_register_filename (const char *fname, int read_only, void **ptr);
--- old/g10/packet.h	2023-04-04 01:28:39 -0700
+++ new/g10/packet.h	2024-10-04 12:47:37 -0700
@@ -30,6 +30,7 @@
 #include "../common/openpgpdefs.h"
 #include "../common/userids.h"
 #include "../common/util.h"
+#include "keyring.h"
 
 #define DEBUG_PARSE_PACKET 1
 
--- old/g13/Makefile.in	2024-03-07 05:45:52 -0800
+++ new/g13/Makefile.in	2024-10-04 12:54:33 -0700
@@ -530,7 +530,7 @@
 	         $(LIBASSUAN_LIBS) $(GPG_ERROR_LIBS) $(LIBICONV)
 
 t_g13tuple_SOURCES = t-g13tuple.c g13tuple.c
-t_g13tuple_LDADD = $(t_common_ldadd)
+t_g13tuple_LDADD = $(t_common_ldadd) $(LIBINTL)
 all: all-am
 
 .SUFFIXES:
--- old/kbx/keybox.h	2023-05-30 04:44:45 -0700
+++ new/kbx/keybox.h	2024-10-04 00:27:09 -0700
@@ -28,6 +28,7 @@
 
 #include "../common/iobuf.h"
 #include "keybox-search-desc.h"
+#include "../g10/keyring.h"
 
 #ifdef KEYBOX_WITH_X509
 # include <ksba.h>
