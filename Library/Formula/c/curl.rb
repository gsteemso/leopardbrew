# stable release 2025-09-10, checked 2025-09-19.
require 'merge'

class Curl < Formula
  include Merge

  desc 'Get a file from an HTTP, HTTPS or FTP server'
  homepage 'https://curl.se/'
  url 'https://curl.se/download/curl-8.16.0.tar.xz'
  sha256 '40c8cddbcb6cc6251c03dea423a472a6cea4037be654ba5cf5dec6eb2d22ff1d'

  keg_only :provided_by_osx

  option :universal

  option 'with-gnutls',        'Add GnuTLS security, independent of OpenSSL/LibreSSL'
  option 'with-rtmpdump',      'Support RTMP (streaming Flash)'
  option 'with-standalone',    'Omit every discretionary dependency except OpenSSL3'
  option 'with-tests',         'Run the build‐time test suite (slow and requires Python3)'

  option 'without-dns-extras', 'Omit asynchronous, internationalized, public‐suffix‐aware DNS'
  option 'without-gsasl',      'Omit Simple Authentication & Security Layer SCRAM authentication'
  option 'without-kerberos',   'Support GSS-API and SPNEGO authentication (via MIT Kerberos)'
  option 'without-libssh2',    'Omit scp and sFTP access'
  option 'without-ssl',        'Omit LibreSSL/OpenSSL security (recommend adding GnuTLS)'
  option 'without-zstd',       'Omit ZStandard compression'

  deprecated_option 'with-rtmp'        => 'with-rtmpdump'
  deprecated_option 'with-ssh'         => 'with-libssh2'
  deprecated_option 'without-more-dns' => 'without-dns-extras'

  depends_on :ld64        => :build
  depends_on 'make'       => :build  # pre‐version 4 `make` can be flaky when running parallel jobs
  depends_on 'pkg-config' => :build
  depends_on :python3    => :build if build.with? 'tests'

  depends_on 'curl-ca-bundle'
  depends_on 'libnghttp2'
  depends_on 'libuv'
  depends_on 'openssl3' if build.with?('ssl')
  depends_on 'perl'
  depends_on 'zlib'

  if build.without? 'standalone'
    depends_group ['dns-extras', ['c-ares', 'libidn2', 'libpsl'] => :recommended]
    depends_on     'gsasl'      => :recommended
    depends_on     'kerberos'   => :recommended
    depends_on     'libssh2'    => :recommended
    depends_on     'zstd'       => :recommended

    depends_on 'gnutls'   => :optional
    depends_on 'rtmpdump' => :optional

    enhanced_by 'brotli'
  end

  def install
    # Complain about this, but it doesn’t justify cancelling the build.
    opoo '“--with-standalone” overrides all other “--with-” options except “--with-tests”.  Ignoring them.' \
      if build.with? 'standalone' and (build.with? 'gnutls' or build.with? 'kerberos' or build.with? 'rtmpdump')
    archs = Target.archset
    if build.fat?
      the_binaries = %w[
        bin/curl
        lib/libcurl.4.dylib
        lib/libcurl.a
      ]
      script_to_fix = 'bin/curl-config'
    end # fat?

    # The defaults:
    #   --with-aix-soname=aix*, --enable-alt-svc,  --with-apple-idn*, --disable-ares, --enable-aws,
    #   --enable-basic-auth, --enable-bearer-auth, --enable-bindlocal, --with-brotli,
    #   --without-ca-bundle, --without-ca-embed, --without-ca-fallback, --without-ca-path,
    #   --enable-ca-search*, --disable-ca-search-safe, --disable-code-coverage, --enable-cookies,
    #   --disable-curldebug, --enable-dateparse, --disable-debug, --without-default-ssl-backend,
    #   --enable-dependency-tracking(?), --enable-dict, --enable-digest-auth, --enable-dnsshuffle,
    #   --enable-docs, --enable-doh, --enable-ech*, --enable-fast-install, --enable-file,
    #   --with-fish-functions-dir, --enable-form-api, --enable-ftp, --enable-get-easy-options,
    #   --without-gnu-ld, --enable-gopher, --without-gssapi, --enable-headers-api, --enable-hsts,
    #   --enable-http, --enable-http-auth, --disable-httpsrr, --with-hyper, --enable-imap,
    #   --enable-ipfs, --enable-ipv6, --enable-kerberos-auth, --enable-largefile, --enable-ldap,
    #   --enable-ldaps, --enable-libcurl-option, --disable-libgcc, --with-libgsasl, --with-libidn2,
    #   --with-libpsl, --with-librtmp, --without-libssh, --without-libssh2, --enable-libtool-lock,
    #   --with-libuv, --disable-maintainer-mode, --enable-manual, --enable-mime, --disable-mqtt,
    #   --with-msh3, --enable-negotiate-auth, --enable-netrc, --with-nghttp2, --with-nghttp3,
    #   --with-ngtcp2, --enable-ntlm, --disable-openssl-autoload-config, --with-openssl-quic*,
    #   --enable-optimize, --enable-option-checking, --enable-pop3, --enable-progress-meter,
    #   --enable-proxy, enable-pthreads, --with-quiche, --enable-rt, --enable-rtsp,
    #   --enable-sha512-256, --enable-shared, --enable-silent-rules(?), --enable-smb, --enable-smtp,
    #   --enable-socketpair, --disable-ssls-export, --enable-sspi*, --enable-static,
    #   --enable-symbol-hiding*, --enable-telnet, --disable-test-bundles, --enable-tftp,
    #   --enable-threaded-resolver, --enable-tls-srp*, --disable-unity, --enable-unix-sockets,
    #   --enable-verbose, --disable-versioned-symbols, --disable-warnings, --enable-websockets,
    #   --disable-werror, --disable-windows-unicode, --with-winidn*, --with-zlib,
    #   --with-zsh-functions-dir, --with-zstd
    #     At least one must be selected:
    #         --with-amissl      | --with-gnutls[=…] | --with-mbedtls[=…] | --with-openssl[=…]
    #       | --with-rustls[=…]  | --with-schannel   | --with-wolfssl[=…] | --without-ssl
    # * These are enabled by default, but only when possible.  (See below.)
    # These disable nonbinary behaviour:
    #   --with[out]-pic (Normally both; on Mac OS 10.5, shared is with & static is without.)
    #   --with-sysroot=… (Replaces the default.)
    # Options that don't, or don’t always, work for ’brewing:
    #   --with-apple-idn :  Apple IDN is more recent than Power Macs provide.
    #   --enable-ech :  LibreSSL doesn’t do it, and OpenSSL’s isn’t ready yet (and it’s been YEARS).
    #                   Therefore, this is only enabled for GnuTLS.
    #   --with-openssl-quic :  Requires a recent‐enough OpenSSL.
    #   --with-quiche :  QUICHE is only supported on little‐endian platforms.
    #   --with-secure-transport :  Not in Tiger; many versions from Leopard onward are obsolete; &
    #                              cURL loses some features when using it instead of, e.g., OpenSSL.
    #   --enable-symbol-hiding :  Requires compiler support, which Apple’s GCC predates.
    #   --enable-tls-srp :  LibreSSL does not have the API, but it’s automatic on OpenSSL.
    # Inapplicable options:
    #   --with-aix-soname=… :  Only applicable to AIX.
    #   --with-amissl :  AmiSSL is for AmigaOS.
    #   --disable-ca-search :  Unsafe CA search behaviour on Windows.
    #   --enable-ca-search-safe :  Safe CA search behaviour on Windows.
    #   --with-schannel :  Secure Channel is a Windows thing.
    #   --enable-sspi :  SSPI is a Windows thing.
    #   --enable-unity :  Unity is a C# wrapper ecosystem.
    #   --enable-windows-unicode :  Only applicable to Windows.
    #   --with-winidn :  Windows IDN.
    # Options that need packages or similar support, not all of which exist:
    #   --with[out]-brotli[=…] :  A compression protocol.  Use $PKG_CONFIG_PATH instead.
    #   --with[out]-fish-functions-dir=… :  A shell‐completions directory.
    #   --with-gssapi=… :  The GSS‐API directory root.  (Heimdal, or MIT Kerberos… which Mac OS has,
    #                      but we can’t use, because of the order header directories get added in.)
    #     or, --with-gssapi-includes=… :  The GSS‐API headers directory.
    #         --with-gssapi-libs=… :  The GSS‐API libraries directory.
    #   --with[out]-hyper=… :  Hyper is an HTTP library written in Rust, and as such is unavailable
    #                          on Power Macs.
    #   --with-lber-lib=… :  LBER is the Lightweight Basic Encoding Rules library; BER is some kind
    #                        of ASN.1 thing.  Possibly associated with OpenLDAP.
    #   --with-ldap-lib=… :  The LDAP library file.
    #   --with[out]-libidn2=… :  The LibIDN2 directory root.
    #   --with[out]-librtmp=… :  The LibRTMP directory root.
    #   --with-libssh[=…] :  The LibSSH directory root.  Use LibSSH2 (via $PKG_CONFIG_PATH) instead.
    #   --with-libssh2[=…] :  The LibSSH2 directory root.  Use $PKG_CONFIG_PATH instead.
    #   --with[out]-libuv=… :  The LibUV directory root.
    #   --with[out]-nghttp2=…* :  The LibNGHTTP2 directory root.
    #   --with[out]-nghttp3=…* :  The LibNGHTTP3 directory root.
    #   --with[out]-ngtcp2=…* :  the LibNGTCP2 directory root.
    #   --with[out]-quiche=…* :  Google’s “QUIC, Http, Etc.” – HTTP/2 & /3 (QUIC).  No availability
    #                            for big‐endian platforms.
    #   --with-test-caddy=…* :  A test program.
    #   --with-test-httpd=…* :  A test program (from apache; or from libnghttp2, but we don’t build
    #                           it there, for good reasons).
    #   --with-test-nghttpx=…* :  A test program (from libnghttp2, but we don’t build it there, for
    #                             good reasons).
    #   --with-test-vsftpd=… :  A test program.
    #   --with-wolfssh[=…] :  The WolfSSH directory root.  Use $PKG_CONFIG_PATH instead.
    #   --with[out]-zlib[=…]* :  The ZLib directory root.  Use $PKG_CONFIG_PATH instead.
    #   --with[out]-zsh-functions-dir=… :  A shell‐completions directory.
    #   --with[out]-zstd[=…]* :  The Zstandard directory root.  Use $PKG_CONFIG_PATH instead.
    # Installation locations that, if specified, are preferably done via PKG_CONFIG_PATH:
    #   {brotli}, {libpsl}, {(libssh) | libssh2}, {libressl|openssl3}, {rtmpdump}, ({!wolfssh}),
    #   {zlib}, {zstd}
    # Explicitly‐described dependencies (there are others not called out on the cURL website):
    #   For TLS:  any of {OpenSSL, mbed TLS, GnuTLS, NSS, WolfSSL}
    #             (NSS is Mozilla’s Network Security Services package.)
    #   For GSS‐API:  either of {Heimdal, MIT Kerberos}
    #   Other:  Zlib, OpenLDAP, NGHTTP2, C-ARES, LibIDN 2, LibSSH 2
    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking',
      '--disable-silent-rules',
      # Old Mac OSes ship with unusably outdated certs.
      "--with-ca-bundle=#{HOMEBREW_PREFIX}/share/ca-bundle.crt",
      '--with-ca-fallback',
      '--enable-httpsrr',
      '--enable-mqtt',
      '--enable-ssls-export',
      "--with-fish-functions-dir=#{fish_completion}",
      "--with-zsh-functions-dir=#{zsh_completion}"
    ]
    args << '--enable-libgcc' if ENV.compiler != :clang

    # cURL now prefers to find lots of things via pkg-config instead of using “--with-xxx=”:  “When
    # possible, set the PKG_CONFIG_PATH environment variable instead of using this option.”  Choice
    # among multiple SSLs breaks without doing this.  That said, the prerequisites‐assembly process
    # already sets $PKG_CONFIG_PATH for us, so it doesn’t much matter.

    args << '--with-gnutls' << '--enable-ech' if build.with? 'gnutls'
    if build.with? 'ssl'
      args << '--with-openssl' << '--enable-openssl-auto-load-config'
    elsif build.without? 'gnutls'
      args << '--without-ssl'
    end

    if build.with? 'dns-extras'
      args << '--enable-ares'
    else
      args << '--without-libidn2' << '--without-libpsl'
    end

    args << '--without-brotli' unless enhanced_by? 'brotli'
    args << "--with-gssapi=#{Formula['kerberos'].opt_prefix}" if build.with? 'kerberos'
    args << '--with-libssh2' if build.with? 'libssh2'
    args << '--without-librtmp' if build.without? 'rtmpdump'
    args << '--without-zstd' if build.without? 'zstd'

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.fat?

      system './configure', *args
      system 'make'
      begin  # tests occasionally suffer a single transient failure that goes away when retried
        tests_attempted = false
        system 'make', 'check', "TFLAGS=-j#{ENV.make_jobs.to_s}"
      rescue
        unless tests_attempted
          tests_attempted = true
          retry
        else
          raise
        end
      end if build.with? 'tests'
      system 'make', 'install'
      # Install the shell‐completion scripts.
      system 'make', 'install', '-C', 'scripts'
      libexec.install 'scripts/mk-ca-bundle.pl' if File.exists? 'scripts/mk-ca-bundle.pl'

      if build.fat?
        ENV.deparallelize { system 'make', '-ik', 'maintainer-clean' }
        merge_prep(:binary, arch, the_binaries)
      end # fat?
    end # each |arch|

    if build.fat?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
      inreplace prefix/script_to_fix, %r{-arch [0-9a-z_]+}, archs.as_arch_flags
    end # fat?
  end # install

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    for_archs bin/'curl' do |arch, cmd|
      filename = testpath/"test-#{arch}.tar.gz"
      system *cmd, '-L', stable.url, '-o', filename.to_s
      filename.verify_checksum stable.checksum
      filename.delete
    end

    if Formula['perl'].installed?
      ENV.prepend_path 'PATH', Formula['perl'].opt_bin
      # so mk-ca-bundle can find it
      ENV.prepend_path 'PATH', Formula['curl'].opt_bin
      system "#{libexec}/mk-ca-bundle.pl", '-i', 'test.pem'
      assert File.exists?('test.pem')
      assert File.exists?('certdata.txt')
    end # Perl?
  end # test
end # Curl
