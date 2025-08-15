# This won’t build fat under a stock compiler because, while only the 64‐bit slices of
# libgcc_s.1.dylib contain a “___multi3” function (which operates on 64‐bit registers), for some
# reason a fat build tries to also call it from 32‐bit slices.
require 'merge'

class Kerberos < Formula
  include Merge

  desc 'MIT’s implementation of Kerberos version 5 authentication'
  homepage 'https://kerberos.org/'
  url 'https://kerberos.org/dist/krb5/1.21/krb5-1.21.3.tar.gz'
  version '1.21.3'
  sha256 'b7a4cd5ead67fb08b980b21abd150ff7217e85ea320c9ed0c6dadd304840ad35'

  keg_only :provided_by_osx

  option :universal
  option 'without-nls', 'Build without Natural Language Support (internationalization)'
  option 'without-test-dns', 'Don’t pull in resolv-wrapper for the build-time unit tests'

#  depends_on :ld64
  depends_on 'pkg-config'       => :build
  depends_on :python            => :build  # used during unit testing
  if build.with? 'test-dns'
    depends_on 'resolv_wrapper' => :build
  end
  depends_on 'openssl3'
  depends_on :nls => :recommended

  patch :DATA

  resource 'macos_extras_tiger_snowleopard' do
    url 'http://web.mit.edu/macdev/Download/Mac_OS_X_10.4_10.6_Kerberos_Extras.dmg'
    sha256 'ed2ee956ceab45dfcbdf06afcaae7f78afbb2afece536e41b1fc991b4407ae9e'
  end if MacOS.version <= :snow_leopard

  def install
    if build.universal?
      archs = CPU.local_archs
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
    else
      archs = [MacOS.preferred_arch]
    end # universal?

	# Not even stock pkg-config knows about stock libedit, so we have to describe it by hand.
    ENV['LIBEDIT_CFLAGS'] = '-I/usr/include/editline'
    ENV['LIBEDIT_LIBS'] = '-ledit'

    cd 'src' do
	  archs.each do |arch|
		ENV.set_build_archs(arch) if build.universal?

		system './configure', "--prefix=#{prefix}",
							  '--with-crypto-impl=openssl',
							  '--with-libedit'
		system 'make'
		system 'make', 'check'
		system 'make', 'install'

		if build.universal?
		  ENV.deparallelize { system 'make', 'distclean' }
		  merge_prep(:binary, arch, the_binaries)
		end # universal?
	  end # each |arch|
    end # cd src

    if build.universal?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
    end # universal?

    pkgshare.install resource('macos_extras_tiger_snowleopard') if MacOS.version <= :snow_leopard
  end # install

  test do
    system 'false'
  end
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
# $(RUN_TEST) has the slight problem that no configuration file yet exists!
--- old/src/lib/krb5/os/Makefile.in
+++ new/src/lib/krb5/os/Makefile.in
@@ -8,6 +8,9 @@
 RUN_TEST_LOCAL_CONF=$(RUN_SETUP) KRB5_CONFIG=$(srcdir)/td_krb5.conf LC_ALL=C \
 	$(VALGRIND)
 
+RUN_TEST_W_CONF=$(RUN_SETUP) KRB5_CONFIG=$(top_srcdir)/config-files/krb5.conf \
+	LC_ALL=C $(VALGRIND)
+
 ##DOS##BUILDTOP = ..\..\..
 ##DOS##PREFIXDIR=os
 ##DOS##OBJFILE=..\$(OUTPRE)$(PREFIXDIR).lst
@@ -222,7 +225,7 @@
 	if [ "$(OFFLINE)" = no ]; then \
 	    if $(DIG) $(SRVNAME) srv | grep -i $(DIGPAT) || \
 		$(NSLOOKUP) -q=srv $(SRVNAME) | grep -i $(NSPAT); then \
-		$(RUN_TEST) ./t_locate_kdc $(LOCREALM); \
+		$(RUN_TEST_W_CONF) ./t_locate_kdc $(LOCREALM); \
 	    else \
 		echo '*** WARNING: skipped t_locate_kdc test: known DNS name not found'; \
 		echo 'Skipped t_locate_kdc test: known DNS name not found' >> $(SKIPTESTS); \
