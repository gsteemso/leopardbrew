# stable release 2026-06-24, checked 2026-08-06.
require 'merge'

class Curl < Formula
  include Merge

  desc 'Get a file from an HTTP, HTTPS or FTP server'
  homepage 'https://curl.se/'
  url 'https://curl.se/download/curl-8.21.0.tar.xz'
  sha256 'aa1b66a70eace83dc624508745646c08ae561de512ab403adffb93ac87fc72e6'

  keg_only :provided_by_osx

  option :tests,    'Run the build‐time test suite (slow and requires Python3)'
  option :universal

  option 'with-gnutls',        'Add GnuTLS security, independent of OpenSSL'

  option 'without-dns-extras', 'Omit asynchronous, internationalized, public‐suffix‐aware DNS'
  option 'without-frills',     'Omit every discretionary dependency except OpenSSL3'
  option 'without-gsasl',      'Omit Simple Authentication & Security Layer SCRAM authentication'
  option 'without-kerberos',   'Omit MIT Kerberos support for GSS-API and SPNEGO authentication'
  option 'without-libssh2',    'Omit scp and sFTP access'
  option 'without-ssl',        'Omit OpenSSL security (recommend adding GnuTLS)'

  deprecated_option 'with-ssh'         => 'with-libssh2'
  deprecated_option 'without-more-dns' => 'without-dns-extras'

  depends_on :ld64        => :build
  depends_on 'make'       => :build  # Pre‐version 4 `make` can apparently be flaky when running parallel jobs.
  depends_on 'pkg-config' => :build
  depends_on :python3     => :build if build.with? 'tests'

  depends_on 'curl-ca-bundle'
  depends_on 'libnghttp2'
  depends_on 'libuv'
  depends_on 'openssl3' if build.with?('ssl')
  depends_on 'perl'
  depends_on 'zlib'

  if build.with? 'frills'
    depends_group ['dns-extras', ['c-ares', 'libidn2', 'libpsl'] => :recommended]
    depends_on     'gsasl'      => :recommended
    depends_on     'kerberos'   => :recommended
    depends_on     'libssh2'    => :recommended

    depends_on 'gnutls'   => :optional
  end

  enhanced_by 'brotli'   # Cannot be a hard dependency, due to a dependency loop through CMake.
  enhanced_by 'openssh'  # While the old stock versions technically work, the newer ones work a lot better.
  enhanced_by 'zstd'

  def install
    if build.universal?
      Target.allow_universal_binary
      the_binaries = %w[
        bin/curl
        lib/libcurl.4.dylib
        lib/libcurl.a
      ]
      script_to_fix = 'bin/curl-config'
    end # universal?
    archs = Target.archset

    # The defaults:
    #   --enable-alt-svc,  --with-apple-idn*†, --disable-ares, --enable-aws, --enable-basic-auth, --enable-bearer-auth,
    #   --enable-bindlocal, --disable-ca-native, --disable-code-coverage, --enable-cookies, --disable-curldebug, --enable-dateparse,
    #   --disable-debug, --without-default-ssl-backend, --enable-dependency-tracking(?), --enable-dict, --enable-digest-auth,
    #   --enable-dnsshuffle, --enable-docs, --enable-doh, --disable-ech†, --enable-file, --enable-form-api, --enable-ftp,
    #   --enable-get-easy-options, --enable-gopher, --enable-headers-api, --enable-hsts, --enable-http, --enable-http-auth,
    #   --disable-httpsrr, --enable-imap, --disable-init-mem-debug, --enable-ipfs, --enable-ipv6, --enable-kerberos-auth,
    #   --enable-largefile, --enable-ldap, --enable-ldaps, --enable-libcurl-option, --disable-libgcc, --enable-libtool-lock,
    #   --disable-maintainer-mode, --enable-manual, --enable-mime, --disable-mqtt, --enable-negotiate-auth, --enable-netrc,
    #   --disable-openssl-auto-load-config, --enable-optimize, --enable-option-checking, --enable-pop3, --enable-progress-meter,
    #   --enable-proxy, --disable-proxy-http3, --enable-rt, --enable-rtsp, --enable-sha512-256, --enable-shared,
    #   --enable-silent-rules(?), --enable-smtp, --enable-socketpair, --disable-ssls-export, --enable-static,
    #   --enable-symbol-hiding*†, --enable-telnet, --enable-tftp, --enable-threaded-resolver, --enable-typecheck,
    #   --enable-unix-sockets, --enable-verbose, --disable-versioned-symbols, --disable-warnings, --enable-websockets,
    #   --disable-werror
    #   One may be selected:
    #     --with-apple-sectrust† | --with-ca-bundle=… | --with-ca-embed=… |--with-ca-path=…
    #     Additionally, --with-ca-fallback may be specified under OpenSSL.
    #   * These are enabled by default, but only when possible.  (See below.)
    #   † Options from the above that don't, or don’t always, work for ’brewing:
    #     --with-apple-idn :  Apple IDN is more recent than Power Macs provide.
    #     --with-apple-sectrust:  Likewise.
    #     --enable-ech :  This is experimental and not for production use.
    #     --enable-symbol-hiding :  Requires compiler support, which Apple’s GCC predates.
    #   At least one must be selected:
    #     (--with-amissl) | --with-gnutls=… | --with-mbedtls=… | --with-openssl=… | --with-rustls=… | (--with-schannel)
    #     | --with-wolfssl=… | --without-ssl
    #   (OpenSSL also includes AWS-LC, BoringSSL, LibreSSL, & quictls.  It is mutually exclusive with WolfSSL due to symbol names.)
    #   Multi-SSL and HTTP/3 are mutually exclusive.  HTTP/3 requires {libnghttp3}, {libngtcp2}, & one of [{openssl3} or one of the
    #   alternates just listed] | {gnutls} | {!wolfssl}.
    # These disable nonbinary behaviour:
    #   --with[out]-pic[=<packages>] (Normally both; on Mac OS 10.5, shared is with & static is without; on 10.4, both are without.)
    #   --with-sysroot[=…] (Replaces the default.)
    # Inapplicable options:
    #   --with-aix-soname=… :  Only applicable to AIX.
    #   --with-amissl :  AmiSSL is for AmigaOS.
    #   --enable-ca-search :  Unsafe CA search behaviour on Windows.
    #   --enable-ca-search-safe :  Safe CA search behaviour on Windows.
    #   --enable-fast-install :  A LibTool optimization inapplicable on Mac OS.
    #   --with-gnu-ld :  Inapplicable on Mac OS.
    #   --with-schannel :  Secure Channel is a Windows thing.
    #   --enable-sspi :  SSPI is a Windows thing.
    #   --enable-unity :  Unity is a C# wrapper ecosystem.
    #   --enable-windows-unicode :  Only applicable to Windows.
    #   --with-winidn :  Windows IDN.
    # Options that need packages or similar support, not all of which exist:
    #   --enable-backtrace :  Link with libbacktrace.
    #   --with[out]-brotli[=…] :  A compression protocol.  Use $PKG_CONFIG_PATH instead.
    #   --with[out]-fish-functions-dir=… :  A shell‐completions directory.
    #   --with-gssapi=… :  The GSS‐API directory root.  (Heimdal, or MIT Kerberos… which Mac OS has, but we can’t use, due to which
    #                      order header directories get added in.)
    #     or, --with-gssapi-includes=… :  The GSS‐API headers directory.
    #         --with-gssapi-libs=… :  The GSS‐API libraries directory.
    #   --with-lber-lib=… :  LBER = Lightweight “Basic Encoding Rules” (an ASN.1 thing) library.  May be associated with OpenLDAP.
    #   --with[out]-ldap[=…] :  The LDAP directory root.  Use $PKG_CONFIG_PATH instead.
    #     or, --with-ldap-lib=… :  The LDAP library file.
    #   --with[out]-libgsasl[=…] :  The LibGSASL directory root.  Use $PKG_CONFIG_PATH instead.
    #   --with[out]-libidn2[=…] :  The LibIDN2 directory root.
    #   --with[out]-libpsl[=…] :  The LibPSL directory root.  Use $PKG_CONFIG_PATH instead.
    #   --with-libssh[=…] :  The LibSSH directory root.  Use LibSSH2 (via $PKG_CONFIG_PATH) instead.
    #   --with-libssh2[=…] :  The LibSSH2 directory root.  Use $PKG_CONFIG_PATH instead.
    #   --with[out]-libuv[=…] :  The LibUV directory root.
    #   --with[out]-nghttp2[=…]* :  The LibNGHTTP2 directory root.
    #   --with[out]-nghttp3[=…]* :  The LibNGHTTP3 directory root.
    #   --with[out]-ngtcp2[=…]* :  the LibNGTCP2 directory root.
    #   --with[out]-quiche[=…]* :  Google’s “QUIC, Http, Etc.” – HTTP/2 & /3 (QUIC).  No availability for big‐endian platforms.
    #   --with-test-caddy=…* :  A test program.
    #   --with-test-danted=… :  A SOCKS test dæmon.
    #   --with-test-httpd=…* :  A test program (from apache; or from libnghttp2, but we don’t build it there, for good reasons).
    #   --with-test-h2o=… :  A test program.
    #   --with-test-nghttpx=…* :  A test program (from libnghttp2, but we don’t build it there, for good reasons).
    #   --with-test-sshd=… :  Where to find sshd for testing.
    #   --with-test-vsftpd=… :  A test program.
    #   --with[out]-zlib[=…]* :  The ZLib directory root.  Use $PKG_CONFIG_PATH instead.
    #   --with[out]-zsh-functions-dir[=…] :  A shell‐completions directory.
    #   --with[out]-zstd[=…]* :  The Zstandard directory root.  Use $PKG_CONFIG_PATH instead.
    # Installation locations that, if specified, are preferably done via PKG_CONFIG_PATH:
    #   {brotli}, {!ldap}, {gsasl}, {libpsl}, {(libssh) | libssh2}, {libressl|openssl3}, {zlib}, {zstd}
    # Explicitly‐described dependencies (there are others not called out on the cURL website):
    #   For TLS:  any of {OpenSSL, mbed TLS, GnuTLS, WolfSSL}
    #   For GSS‐API:  either of {Heimdal, MIT Kerberos}
    #   Other:  Zlib, OpenLDAP, NGHTTP2, C-ARES, LibIDN2, LibSSH2
    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking',
      '--disable-silent-rules',
      "--with-ca-bundle=#{HOMEBREW_PREFIX}/share/ca-bundle.crt",  # Older Mac OSes ship with unusably outdated certificates.
      '--enable-mqtt',
      "--with-fish-functions-dir=#{fish_completion}",
      "--with-zsh-functions-dir=#{zsh_completion}"
    ]
    args << '--with-ca-fallback' if build.with? 'ssl'
#    args << '--enable-libgcc' if ENV.compiler.to_s.starts_with? 'gcc'

    # cURL now prefers to find most things via pkg-config instead of using “--with-xxx=”.  Using multiple SSLs breaks without doing
    # this.  That said, the prerequisites‐assembly process already sets $PKG_CONFIG_PATH for us, so it doesn’t much matter.

    args << '--with-gnutls' if build.with? 'gnutls'

    if build.with?('ssl') then args << '--with-openssl' << '--enable-openssl-auto-load-config'
    elsif build.without?('gnutls') then args << '--without-ssl'; end

    if build.with? 'frills' and build.with? 'dns-extras' then args << '--enable-ares'
    else args << '--without-libidn2' << '--without-libpsl'; end

    if build.with? 'frills'
      args << '--with-libgsasl' if build.with? 'gsasl'
      args << "--with-gssapi=#{Formula['kerberos'].opt_prefix}" if build.with? 'kerberos'
      args << '--with-libssh2' if build.with? 'libssh2'
    end

    args << (active_enhancement_names.include?('brotli') ? '--with-brotli' : '--without-brotli')
    args << (active_enhancement_names.include?('zstd'  ) ? '--with-zstd'   : '--without-zstd'  )

    mkdir 'build'

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.universal?
      cd 'build' do
        checkpoint arch do
          system './configure', *args
          system 'make'
          if build.with? 'tests'
            tests_attempted = false
            begin  # tests occasionally suffer a single transient failure that goes away when retried
              system 'make', 'check', "TFLAGS=-j#{ENV.make_jobs.to_s}"
            rescue
              unless tests_attempted
                tests_attempted = true
                retry
              else
                raise
              end # tests attempted?
            end # rescue
          end # build with tests?
        end # checkpoint
        system 'make', 'install'
        system 'make', 'install', '-C', 'scripts'  # Install the shell‐completion scripts.
        libexec.install 'scripts/mk-ca-bundle.pl' if File.exists? 'scripts/mk-ca-bundle.pl'
        if build.universal?
          ENV.deparallelize { system 'make', '-ik', 'maintainer-clean' }
          merge_prep(:binary, arch, the_binaries)
        end # universal?
      end # cd build/
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
      inreplace prefix/script_to_fix, %r{-arch [0-9a-z_]+}, archs.as_arch_flags
    end # universal?
  end # install

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    for_archs bin/'curl' do |arch, cmd|
      filename = testpath/"test-#{arch}.tar.gz"
      system *cmd, '-L', stable.url, '-o', filename.to_s
      filename.verify_checksum stable.checksum
      filename.delete
    end # for_archs bin/curl
    if Formula['perl'].any_version_installed?
      ENV.prepend_path 'PATH', [Formula['perl'].opt_bin, Formula['curl'].opt_bin]  # So mk-ca-bundle can find them.
      system "#{libexec}/mk-ca-bundle.pl", '-fin', 'test.pem'
      with_assertion { assert (File.real_file?('certdata.txt') and File.real_file? 'test.pem') }
    end # Perl?
  end # test
end # Curl
