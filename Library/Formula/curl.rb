class Curl < Formula
  desc 'Get a file from an HTTP, HTTPS or FTP server'
  homepage 'https://curl.se/'
  url 'https://curl.se/download/curl-8.11.1.tar.xz'
  sha256 'c7ca7db48b0909743eaef34250da02c19bc61d4f1dcedd6603f109409536ab56'

  keg_only :provided_by_osx

  option :universal
  option 'with-gnutls',   'Add GnuTLS security, independent of OpenSSL/LibreSSL'
  option 'with-libressl', 'Use LibreSSL security instead of OpenSSL'
  option 'with-rtmpdump', 'Add RTMP (streaming Flash) capability'
  option 'with-tests',    'Run the build‐time test suite (slow)'
  option 'without-gsasl',    'Omit SASL SCRAM authentication'
  option 'without-libssh2',  'Omit scp and sFTP access'
  option 'without-more-dns', 'Omit asynchronous, internationalized, public‐suffix‐aware DNS'
  option 'without-ssl',      'Omit LibreSSL/OpenSSL security (recommend adding GnuTLS)'
  option 'without-zstd',     'Omit ZStandard compression'

  deprecated_option 'with-rtmp'   => 'with-rtmpdump'
  deprecated_option 'with-ssh'    => 'with-libssh2'

  depends_on 'pkg-config' => :build

  depends_on 'curl-ca-bundle'
  depends_on 'libnghttp2'
  depends_on 'libuv'
  depends_on 'openssl3' if build.with?('ssl') and build.without? 'libressl'
  depends_on 'perl'
  depends_on 'zlib'

  depends_on    'gsasl'   => :recommended
  depends_on    'libssh2' => :recommended
  depends_group ['more-dns', ['c-ares', 'libidn2', 'libpsl']
                ]         => :recommended
  depends_on    'zstd'    => :recommended

  depends_on 'gnutls'   => :optional
  depends_on 'libressl' => :optional
  depends_on 'rtmpdump' => :optional

  enhanced_by 'brotli'

  def install
    raise UsageError, '“--with-libressl” and “--without-ssl” are mutually exclusive.  Pick one.' \
                             if build.with? 'libressl' and build.without? 'ssl'
    if build.universal?
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
      the_binaries = %w[
        bin/curl
        lib/libcurl.4.dylib
        lib/libcurl.a
      ]
      script_to_fix = 'bin/curl-config'
    else
      archs = [MacOS.preferred_arch]
    end # universal?

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
    #   --with-ngtcp2, --enable-ntlm, --•?•able-openssl-autoload-config, --with-openssl-quic*,
    #   --enable-optimize, --enable-option-checking, --enable-pop3, --enable-progress-meter,
    #   --enable-proxy, enable-pthreads, --with-quiche, --enable-rt, --enable-rtsp,
    #   --enable-sha512-256, --enable-shared, --enable-silent-rules(?), --enable-smb, --enable-smtp,
    #   --enable-socketpair, --enable-sspi*, --enable-static, --enable-symbol-hiding*,
    #   --enable-telnet, --disable-test-bundles, --enable-tftp, --enable-threaded-resolver,
    #   --enable-tls-srp*, --disable-unity, --enable-unix-sockets, --enable-verbose,
    #   --disable-versioned-symbols, --disable-warnings, --enable-websockets, --disable-werror,
    #   --disable-windows-unicode, --with-winidn*, --with-zlib, --with-zsh-functions-dir,
    #   --with-zstd
    # At least one must be selected:
    #     --with-amissl      | --with-bearssl[=…] | --with-gnutls[=…] | --with-mbedtls[=…]
    #   | --with-openssl[=…] | --with-rustls[=…]  | --with-schannel   | --with-secure-transport
    #   | --with-wolfssl[=…] | --without-ssl
    # * These are enabled by default, but only when possible.  (See below.)
    # These disable nonbinary behaviour:
    #   --with[out]-pic (Normally both; on Mac OS 10.5, shared is with & static is without.)
    #   --with-sysroot=… (Replaces the default.)
    # Options that don't, or don’t always, work for ’brewing:
    #   --with-apple-idn :  Apple IDN is more recent than Power Macs provide.
    #   --enable-ech :  LibreSSL doesn’t do it & OpenSSL’s isn’t released yet (and it’s been YEARS).
    #                   That’s why this is only enabled if GNUTLS is selected.
    #   --with-openssl-quic :  Requires a specific non‐OpenSSL build and is not well supported.
    #   --with-quiche :  QUICHE is only supported on little‐endian platforms.
    #   --with-secure-transport :  Not in Tiger; many versions from Leopard onward are obsolete; &
    #                              cURL loses some features when using it instead of, e.g., OpenSSL
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
    # Options not mentioned above because they need packages, which may or may not already exist:
    #   --with[out]-brotli[=…] :  A compression protocol.
    #   --with[out]-fish-functions-dir=… :  The FISh completions directory.
    #   --with-gssapi=… :  The GSS‐API directory root.
    #     or, --with-gssapi-includes=… :  The GSS‐API headers directory.
    #         --with-gssapi-libs=… :  The GSS‐API libraries directory.
    #   --with[out]-hyper=… :  Hells if I know.
    #   --with-lber-lib=… :  The LBER library file.
    #   --with-ldap-lib=… :  The LDAP library file.
    #   --with[out]-libidn2=… :  The LibIDN2 file.
    #   --with[out]-librtmp=… :  The LibRTMP file.
    #   --with-libssh[=…] :  The LibSSH file.
    #   --with-libssh2[=…] :  The LibSSH2 file.
    #   --with[out]-libuv=… :  The LibUV file.
    #   --with[out]-nghttp2=…* :  The LibNGHTTP2 file.
    #   --with[out]-nghttp3=…* :  The LibNGHTTP3 file.
    #   --with[out]-ngtcp2=…* (v1.2.0), plus --with-nghttp3 (v1.1.0), plus (--with-gnutls
    #                                                                 OR --with-openssl=quicktls
    #                                                                 OR --with-wolfssl)
    #     OR --with-quiche (quasi‐experimental)
    #   --with[out]-quiche=…* :  Google’s “QUIC, Http, Etc.” – HTTP/2 & –3 (QUIC).
    #   --with-test-caddy=…* :  A test program.
    #   --with-test-httpd=…* :  A test program (from apache, or possibly libnghttp2 if so compiled?).
    #   --with-test-nghttpx=…* :  A test program (from libnghttp2, if so compiled).
    #   --with-test-vsftpd=… :  A test program.
    #   --with-wolfssh[=…] :  The WolfSSH library file.
    #   --with[out]-zlib[=…]* :  The ZLib file.
    #   --with[out]-zsh-functions-dir=… :  The ZSh completions directory.
    #   --with[out]-zstd[=…]* :  A compression protocol.
    # Installation locations that, if specified, are preferably done via PKG_CONFIG_PATH:
    #   {brotli}, {libpsl}, {(libssh) | libssh2}, {libressl|openssl3}, {rtmpdump}, ({!wolfssh}),
    #   {zstd}
    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking',
      '--disable-silent-rules',
      # Old Mac OSes ship with unusably outdated certs.
      "--with-ca-bundle=#{HOMEBREW_PREFIX}/share/ca-bundle.crt",
      '--with-ca-fallback',
      '--with-gssapi',
      '--enable-httpsrr',
      '--enable-libgcc',
      '--enable-mqtt',
      "--with-fish-functions-dir=#{fish_completion}",
      "--with-zsh-functions-dir=#{zsh_completion}"
    ]

    # cURL now wants to find a lot of things via pkg-config instead of using
    # “--with-xxx=”:  “When possible, set the PKG_CONFIG_PATH environment
    # variable instead of using this option.”  Multi-SSL choice breaks without
    # doing this.  On the other hand, the prerequisites‐assembly process sets
    # all of them for us already, so it doesn’t much matter.

    # The documentation is ambiguous as to whether this should be set via
    # ./configure argument or via pkg-config.  Can’t test it until GNUTLS
    # compiles successfully (which needs a newer compiler).
    args << "--with-gnutls=#{Formula['gnutls'].opt_prefix}" if build.with? 'gnutls'

    if build.with? 'libressl'
      args << '--with-openssl'
    elsif build.with? 'ssl'
      args << '--with-openssl'
      args << '--enable-openssl-auto-load-config'
    elsif build.without? 'gnutls'
      args << '--without-ssl'
    end

    if build.with? 'more-dns'
      args << '--enable-ares'
    else
      args << '--without-libidn2' << '--without-libpsl'
    end

    args << '--without-brotli' unless enhanced_by? 'brotli'
    args << '--with-libssh2' if build.with? 'libssh2'
    args << '--without-librtmp' if build.without? 'rtmpdump'
    args << '--without-zstd' if build.without? 'zstd'

    archs.each do |arch|
      ENV.set_build_archs(archs.subset(arch)) if build.universal?

      system './configure', *args
      ENV.deparallelize do
        system 'make'
        system 'make', 'test' if build.with? 'tests'
        system 'make', 'install'
        # Install the shell‐completion scripts.
        system 'make', 'install', '-C', 'scripts'
      end # deparallelize
      libexec.install 'scripts/mk-ca-bundle.pl' if File.exists? 'scripts/mk-ca-bundle.pl'

      if build.universal?
        system 'make', 'clean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        Merge.prep(prefix, stashdir/"script-#{arch}", [script_to_fix])
      end # universal?
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      Merge.binaries(prefix, stashdir, archs)
      inreplace stashdir/"script-#{archs.first}/#{script_to_fix}",
                                    "-arch #{archs.first}", archs.as_arch_flags
      bin.install stashdir/"script-#{archs.first}/#{script_to_fix}"
    end # universal?
  end # install

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/'test.tar.gz')
    arch_system bin/'curl', '-L', stable.url, '-o', filename
    filename.verify_checksum stable.checksum

    # Perl is a dependency of OpenSSL3, so it will /usually/ be present
    if Formula['perl'].installed?
      ENV.prepend_path 'PATH', Formula['perl'].opt_bin
      # so mk-ca-bundle can find it
      ENV.prepend_path 'PATH', Formula['curl'].opt_bin
      system libexec/'mk-ca-bundle.pl', 'test.pem'
      assert File.exist?('test.pem')
      assert File.exist?('certdata.txt')
    end # Perl?
  end # test
end # Curl

class Merge
  class << self
    include FileUtils

    # The keg_prefix and stash_root are expected to be Pathname objects.
    # The list members are just strings.
    def prep(keg_prefix, stash_root, list)
      list.each do |item|
        source = keg_prefix/item
        dest = stash_root/item
        mkdir_p dest.parent
        cp source, dest
      end # each binary
    end # Merge.prep

    # The keg_prefix is expected to be a Pathname object.  The rest are just strings.
    def binaries(keg_prefix, stash_root, archs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dirs = archs.map {|a| "bin-#{a}"}
      arch_dir_list = arch_dirs.join(',')
      Dir["#{stash_root}/{#{arch_dir_list}}/#{s_p}*"].map { |f|
        File.basename(f)
      }.each { |b|
        basename_list << b unless basename_list.count(b) > 0
      }
      basename_list.each do |b|
        spb = s_p + b
        the_arch_dir = arch_dirs.detect { |ad| File.exist?("#{stash_root}/#{ad}/#{spb}") }
        pn = Pathname("#{stash_root}/#{the_arch_dir}/#{spb}")
        if pn.directory?
          binaries(keg_prefix, stash_root, archs, spb)
        else
          arch_files = Dir["#{stash_root}/{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', keg_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, keg_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # each basename |b|
    end # Merge.binaries
  end # << self
end # Merge
