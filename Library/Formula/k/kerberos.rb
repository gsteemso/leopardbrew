# This won’t build fat under a stock compiler because, while only the 64‐bit slices of
# libgcc_s.1.dylib contain a “___multi3” function (which operates on 64‐bit registers), for some
# reason a fat build tries to also call it from 32‐bit slices.
require 'merge'

# Stable release 2025-08-20; checked 2025-09-24.
# Won’t build through `make check` on Tiger due to Heisenbugs.
class Kerberos < Formula
  include Merge

  desc 'MIT’s implementation of Kerberos version 5 authentication'
  homepage 'https://kerberos.org/'
  url 'http://web.mit.edu/kerberos/dist/krb5/1.22/krb5-1.22.1.tar.gz'
  sha256 '1a8832b8cad923ebbf1394f67e2efcf41e3a49f460285a66e35adec8fa0053af'

  keg_only :provided_by_osx

  option :universal
  option 'with-test-dns', 'Allow use of resolv-wrapper for the build-time unit tests'

  depends_on :ld64
  depends_on 'pkg-config'     => :build
  depends_on :python3         => :build  # used during unit testing
  depends_on 'resolv_wrapper' => :build if build.with? 'test-dns'
  depends_on 'openssl3'
  depends_on 'readline'
  depends_on :nls => :recommended

  patch :DATA

  resource 'macos_extras_tiger_snowleopard' do
    url 'http://web.mit.edu/macdev/Download/Mac_OS_X_10.4_10.6_Kerberos_Extras.dmg'
    sha256 'ed2ee956ceab45dfcbdf06afcaae7f78afbb2afece536e41b1fc991b4407ae9e'
  end if MacOS.version >= :tiger and MacOS.version <= :snow_leopard

  def install
    archs = Target.archset
    if build.fat?
      the_binaries = %w[
          bin/gss-client
          bin/kadmin
          bin/kdestroy
          bin/kinit
          bin/klist
          bin/kpasswd
          bin/kswitch
          bin/ktutil
          bin/kvno
          bin/sclient
          bin/sim_client
          bin/uuclient
          lib/krb5/plugins/kdb/db2.so
          lib/krb5/plugins/preauth/otp.so
          lib/krb5/plugins/preauth/pkinit.so
          lib/krb5/plugins/preauth/spake.so
          lib/krb5/plugins/preauth/test.so
          lib/krb5/plugins/tls/k5tls.so
          lib/libcom_err.3.0.dylib
          lib/libgssapi_krb5.2.2.dylib
          lib/libgssrpc.4.2.dylib
          lib/libk5crypto.3.1.dylib
          lib/libkadm5clnt_mit.12.0.dylib
          lib/libkadm5srv_mit.12.0.dylib
          lib/libkdb5.10.0.dylib
          lib/libkrad.0.0.dylib
          lib/libkrb5support.1.1.dylib
          lib/libkrb5.3.3.dylib
          lib/libverto.0.0.dylib
          sbin/gss-server
          sbin/kadmin.local
          sbin/kadmind
          sbin/kdb5_util
          sbin/kprop
          sbin/kpropd
          sbin/kproplog
          sbin/krb5kdc
          sbin/sim_server
          sbin/sserver
          sbin/uuserver
        ]
    end # fat?

    (buildpath/'src/lib/krb5/ccache').install_symlink_to ENV.compiler_path => 'cc'

    # Note that, at least on older Mac OSes, configure can’t recognize the system’s libedit because
    # it’s so outdated.  There could plausibly be some OS‐version threshold after which using stock
    # libedit would reliably work, but it’s easier to just use Readline regardless.
    args = %W[
        --prefix=#{prefix}
        --with-crypto-impl=openssl
        --enable-dns-for-realm
        --with-readline
      ]
    args << '--disable-nls' if build.without? 'nls'
    args << '--disable-thread-support' if MacOS.version < :leopard  # Host‐lookup functions are not
                                                                    # reëntrant prior to Leopard.
    cd 'src' do
      archs.each do |arch|
        ENV.set_build_archs(arch) if build.fat?

        system './configure', *args
        system 'make'
        system 'make', 'check' if MacOS.version > :tiger  # fails on Tiger with bizarre Heisenbugs
        system 'make', 'install'

        if build.fat?
          ENV.deparallelize { system 'make', 'distclean' }
          merge_prep(:binary, arch, the_binaries)
        end # fat?
      end # each |arch|
    end # cd src

    if build.fat?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
    end # fat?

    pkgshare.install resource('macos_extras_tiger_snowleopard') if MacOS.version <= :snow_leopard
  end # install
end # Kerberos

__END__
# The kdc line is needed for when DNS is not available (i.e. during unit testing, if resolv_wrapper
# is unavailable).
--- old/src/config-files/krb5.conf
+++ new/src/config-files/krb5.conf
@@ -5,6 +5,7 @@
 # use "kdc = ..." if realm admins haven't put SRV records into DNS
 	ATHENA.MIT.EDU = {
 		admin_server = kerberos.mit.edu
+		kdc = kerberos.mit.edu:88
 	}
 	ANDREW.CMU.EDU = {
 		admin_server = kdc-01.andrew.cmu.edu
# The parentheses cause older GCCs to read it as a function pointer instead of a string pointer.
--- old/src/include/osconf.hin
+++ new/src/include/osconf.hin
@@ -45,7 +45,7 @@
 #else /* !_WINDOWS */
 #if TARGET_OS_MAC
 #define DEFAULT_SECURE_PROFILE_PATH "/Library/Preferences/edu.mit.Kerberos:/etc/krb5.conf@SYSCONFCONF"
-#define DEFAULT_PROFILE_PATH        ("~/Library/Preferences/edu.mit.Kerberos" ":" DEFAULT_SECURE_PROFILE_PATH)
+#define DEFAULT_PROFILE_PATH        "~/Library/Preferences/edu.mit.Kerberos:" DEFAULT_SECURE_PROFILE_PATH
 #define KRB5_PLUGIN_BUNDLE_DIR       "/System/Library/KerberosPlugins/KerberosFrameworkPlugins"
 #define KDB5_PLUGIN_BUNDLE_DIR       "/System/Library/KerberosPlugins/KerberosDatabasePlugins"
 #define KRB5_AUTHDATA_PLUGIN_BUNDLE_DIR  "/System/Library/KerberosPlugins/KerberosAuthDataPlugins"
# set_msg_from_ipv{n}() are accidentally defined with too many parameters, in the unsupported cases.
--- old/src/lib/apputils/udppktinfo.c
+++ new/src/lib/apputils/udppktinfo.c
@@ -363,7 +363,7 @@
 }
 
 #else /* HAVE_IP_PKTINFO || IP_SENDSRCADDR */
-#define set_msg_from_ipv4(m, c, f, l, a) EINVAL
+#define set_msg_from_ipv4(m, c, f, a) EINVAL
 #endif /* HAVE_IP_PKTINFO || IP_SENDSRCADDR */
 
 #ifdef HAVE_IPV6_PKTINFO
@@ -398,7 +398,7 @@
 }
 
 #else /* HAVE_IPV6_PKTINFO */
-#define set_msg_from_ipv6(m, c, f, l, a) EINVAL
+#define set_msg_from_ipv6(m, c, f, a) EINVAL
 #endif /* HAVE_IPV6_PKTINFO */
 
 static krb5_error_code
