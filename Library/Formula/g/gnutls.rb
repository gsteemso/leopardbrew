# GnuTLS has current stable and next stable branches, we use current.
class Gnutls < Formula
  desc 'GNU Transport Layer Security (TLS) Library'
  homepage 'http://gnutls.org'
  url 'https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-3.7.11.tar.xz'
  mirror 'https://www.mirrorservice.org/sites/ftp.gnupg.org/gcrypt/gnutls/v3.7/gnutls-3.7.11.tar.xz'
  sha256 '90e337504031ef7d3077ab1a52ca8bac9b2f72bc454c95365a1cd1e0e81e06e9'

  # Threads can’t be disabled, but thread-local storage was unsupported on Macs
  # until OS 10.7, and GCC 4.2 did not yet contain the eventual workaround.
  needs :tls

  option :universal
  option 'with-guile', 'Enable extensions written in Scheme'
  option 'with-more-compressors', 'Enable the Brotli and ZStandard compression schemes'
  option 'with-unbound', 'Use the Unbound secure domain‐name resolver'

  depends_on 'pkg-config' => :build
  depends_on 'curl-ca-bundle'
  depends_on 'gmp'
  depends_on 'libev'
  depends_on 'libiconv'
  depends_on 'libidn2'
  depends_on 'libtasn1'
  depends_on 'libunistring'
  depends_on 'nettle'
  depends_on 'p11-kit'
  depends_on 'python3'
  depends_on 'zlib'
  depends_on 'guile'   => :optional
  depends_on 'unbound' => :optional
  depends_group ['more-compressors', ['brotli', 'zstd'] => :optional]

  # Availability.h appeared in Leopard
  patch :DATA

  def install
    ENV.universal_binary if build.universal?
    # make sysconfdir explicit for gnutlsdir
    # disable-doc + enable-manpages works around the gtk-doc dependency
    # openssl compatibility because why not
    args = %W[
      --prefix=#{prefix}
      --sysconfdir=#{etc}
      --disable-dependency-tracking
      --disable-silent-rules
      --disable-doc
      --enable-manpages
      --enable-openssl-compatibility
      --with-default-trust-store-file=#{gnutlsdir}
    ]
    if build.with? 'guile'
      args << '--with-guile-site-dir=no'
    else
      args << '--disable-guile'
    end
    if build.without? 'unbound'
      args << '--disable-libdane'
    end
    ENV['GMP_CFLAGS'] = "-I#{Formula['gmp'].opt_include}"
    ENV['GMP_LIBS'] = "-L#{Formula['gmp'].opt_lib}"
    system './configure', *args
    system 'make', 'install'
    # certtool shadows the OS X certtool utility
    mv bin/'certtool', bin/'gnutls-certtool'
    mv man1/'certtool.1', man1/'gnutls-certtool.1'
  end # install

  def gnutlsdir
    etc/'gnutls'
  end

  def post_install
    rm_f gnutlsdir/'cert.pem'
    gnutlsdir.install_symlink Formula['curl-ca-bundle'].opt_share/'ca-bundle.crt' => 'cert.pem'
  end

  test do
    system bin/'gnutls-cli', '--version'
  end
end

__END__
--- old/lib/system/certs.c	2023-11-28 15:21:28 +0000
+++ new/lib/system/certs.c	2023-11-28 15:20:40 +0000
@@ -47,8 +47,12 @@
 #ifdef __APPLE__
 # include <CoreFoundation/CoreFoundation.h>
 # include <Security/Security.h>
+#ifdef __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__
+#if __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ >= 1050
 # include <Availability.h>
 #endif
+#endif
+#endif
 
 /* System specific function wrappers for certificate stores.
  */
