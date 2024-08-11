class Curl < Formula
  desc "Get a file from an HTTP, HTTPS or FTP server"
  homepage "https://curl.se/"
  url "https://curl.se/download/curl-8.8.0.tar.xz"
  sha256 "0f58bb95fc330c8a46eeb3df5701b0d90c9d9bfcc42bd1cd08791d12551d4400"

  bottle do
    cellar :any
    sha256 "d798c40a4bf32610d49cf5339bd60b9e40db82172bb7b6b895a7e2f1d8ca9807" => :tiger_altivec
  end

  keg_only :provided_by_osx

  option :universal
  option 'with-gnutls',      'Add GnuTLS security, independent of OpenSSL/LibreSSL'
  option 'with-libressl',    'Use LibreSSL security instead of OpenSSL'
  option 'with-libssh2',     'Add scp and sFTP access'
  option 'with-more-dns',    'Add asynchronous, internationalized, public‐suffix‐aware DNS'
  option 'with-rtmpdump',    'Add RTMP (streaming Flash)'
  option 'with-zstd',        'Add ZStandard compression'
  option 'without-gsasl',    'Omit SASL SCRAM authentication'
  option 'without-ssl',      'Omit LibreSSL/OpenSSL security (GnuTLS recommended)'

  deprecated_option "with-ares"   => 'with-more-dns'
  deprecated_option 'with-c-ares' => 'with-more-dns'
  deprecated_option "with-rtmp"   => "with-rtmpdump"
  deprecated_option "with-ssh"    => "with-libssh2"

  depends_on 'gnutls'   => :optional
  depends_on "libressl" => :optional
  depends_on "libssh2"  => :optional
  if build.with? 'more-dns'
    depends_on "c-ares"
    depends_on 'libidn2'  # libPSL also depends on this
    depends_on 'libpsl'
  end
  depends_on "rtmpdump" => :optional
  depends_on 'zstd'     => :optional

  depends_on "gsasl"    => :recommended
  depends_on "openssl3" if build.with?('ssl') and build.without? 'libressl'

  depends_on "libnghttp2"
  depends_on "zlib"

  depends_on "pkg-config" => :build

  def install
    if build.with? 'libressl' and build.without? 'ssl'
      raise '“--with-libressl” and “--without-ssl” are mutually exclusive.  Pick one.'
    end
    if build.universal?
      ENV.permit_arch_flags if superenv?
      ENV.un_m64 if Hardware::CPU.family == :g5_64
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

    # the defaults:
    #   --enable-alt-svc, --enable-bindlocal, --enable-cookies, --disable-curldebug,
    #   --enable-dateparse, --disable-debug --without-default-ssl-backend, --enable-dict,
    #   --enable-docs, --enable-doh, --disable-ech*, --enable-file, --enable-form-api, --enable-ftp,
    #   --enable-gopher, --enable-headers-api, --enable-hsts, --enable-http, --enable-http-auth,
    #   --disable-httpsrr, --enable-imap, --enable-ipv6, --enable-ldap, --enable-ldaps,
    #   --enable-libcurl-option, --with-libidn2, --with-libnghttp2, --with-libpsl, --enable-manual,
    #   --enable-mime, --enable-ntlm, --without-openssl-quic*, --enable-optimize, --enable-pop3,
    #   --enable-proxy, --enable-rt, --enable-rtsp, --without-secure-transport*, --enable-smb,
    #   --enable-smtp, --enable-socketpair, --enable-symbol-hiding*, --enable-telnet, --enable-tftp,
    #   --enable-threaded-resolver, --enable-tls-srp*, --enable-unix-sockets, --enable-verbose,
    #   --disable-warnings, --disable-werror
    #   * these are really _enabled_ by default, but only when possible.
    # options that don't, or don’t always, work for ’brewing:
    #   --enable-ech :  LibreSSL doesn’t do it and OpenSSL isn’t being picked up
    #   --with-openssl-quic (would also provide HTTP/3) :  Ditto
    #   --with-secure-transport :  no Tiger version, many from Leopard on are obsolete, & cURL
    #                              misses some features when using it instead of, e.g., OpenSSL
    #   --enable-tls-srp :  LibreSSL does not have the API, but it’s automatic on OpenSSL
    # options not listed above, as they need packages:
    #   --with-ngtcp2 plus --with-nghttp3
    #     OR --with-msh3
    #     OR --with-quiche
    #   --enable-websockets
    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking',
      '--enable-mqtt',
      '--enable-symbol-hiding',  # Apple GCC does not comply; request anyway because some others do
      '--with-ca-fallback',
      '--with-gssapi',
      "--with-zlib=#{Formula["zlib"].opt_prefix}",
      "--with-fish-functions-dir=#{fish_completion}",
      "--with-zsh-functions-dir=#{zsh_completion}"
    ]

    # cURL has a new firm desire to find ssl with PKG_CONFIG_PATH instead of using
    # "--with-ssl" any more.  "when possible, set the PKG_CONFIG_PATH environment
    # variable instead of using this option".  Multi-SSL choice breaks w/o using it.
    if build.with? 'gnutls'
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['gnutls'].opt_lib}/pkgconfig"
      args << "--with-gnutls=#{Formula['gnutls'].opt_prefix}"
    end
    if build.with? "libressl"
      ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["libressl"].opt_lib}/pkgconfig"
      args << "--with-openssl=#{Formula["libressl"].opt_prefix}"
    elsif build.with? 'ssl'
      ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["openssl3"].opt_lib}/pkgconfig"
      args << "--with-openssl=#{Formula["openssl3"].opt_prefix}"
      args << '--enable-openssl-auto-load-config'
    elsif build.without? 'gnutls'
      args << '--without-ssl'
    end

    # take advantage of Brotli compression if it is installed:
    if Formula['brotli'].installed?
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['brotli'].opt_lib}/pkgconfig"
      args << "--with-brotli=#{Formula['brotli'].opt_prefix}"
    else
      args << '--without-brotli'
    end

    if build.with? 'libssh2'
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['libssh2'].opt_lib}/pkgconfig"
      args << '--with-libssh2'
    else
      args << '--without-libssh2'
    end

    if build.with? 'more-dns'
      args << '--enable-ares'
    else
      args << '--disable-ares' << '--without-libidn2' << '--without-libpsl'
    end

    if build.with? 'rtmpdump'
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['rtmpdump'].opt_lib}/pkgconfig"
      args << '--with-librtmp'
    else
      args << '--without-librtmp'
    end

    if build.with? 'zstd'
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['zstd'].opt_lib}/pkgconfig"
      args << '--with-zstd'
    else
      args << '--without-zstd'
    end

    # Tiger/Leopard ship with a horrendously outdated set of certs,
    # breaking any software that relies on curl, e.g. git
    args << "--with-ca-bundle=#{HOMEBREW_PREFIX}/share/ca-bundle.crt"

    archs.each do |arch|
      if build.universal?
        case arch
          when :i386, :ppc then ENV.m32
          when :ppc64, :x86_64 then ENV.m64
        end
      end # universal?

      ENV.deparallelize do
        system "./configure", *args
        system "make"
        system "make", "install"
        system "make", "install", "-C", "scripts"
      end # deparallelize
      libexec.install "scripts/mk-ca-bundle.pl" if File.exists? 'scripts/mk-ca-bundle.pl'

      if build.universal?
        system 'make', 'clean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        Merge.cp_mkp prefix/script_to_fix, stashdir/"script-#{arch}/#{script_to_fix}"
        # undo architecture-specific tweaks before next run
        case arch
          when :i386, :ppc then ENV.un_m32
          when :ppc64, :x86_64 then ENV.un_m64
        end # case arch
      end # universal?
    end # each |arch|

    if build.universal?
      Merge.binaries(prefix, stashdir, archs)
      archs.extend ArchitectureListExtension
      inreplace stashdir/"script-#{archs.first}/#{script_to_fix}", "-arch #{archs.first}", archs.as_arch_flags
      bin.install stashdir/"script-#{archs.first}/#{script_to_fix}"
    end # universal?
  end # install

  def caveats
    <<-_.undent
      cURL is built with the ability to use Brotli compression, if that formula is
      already installed when cURL is brewed.  (Brotli can’t be auto‐brewed as a cURL
      dependency because it depends on CMake, which depends back on cURL.)
    _
  end # caveats

  test do
    # Fetch the curl tarball and see that the checksum matches.
    # This requires a network connection, but so does Homebrew in general.
    filename = (testpath/"test.tar.gz")
    system "#{bin}/curl", "-L", stable.url, "-o", filename
    filename.verify_checksum stable.checksum

    # Perl is a dependency of OpenSSL3, so it will /usually/ be present
    if Formula['perl'].installed?
      ENV.prepend_path 'PATH', Formula['perl'].opt_bin
      # so mk-ca-bundle can find it
      ENV.prepend_path "PATH", Formula["curl"].opt_bin
      system libexec/"mk-ca-bundle.pl", "test.pem"
      assert File.exist?("test.pem")
      assert File.exist?("certdata.txt")
    end # Perl?
  end # test
end # Curl

class Merge
  class << self
    include FileUtils

    # The destination is expected to be a Pathname object.
    # The source is just a string.
    def cp_mkp(source, destination)
      if destination.exists?
        if destination.is_directory?
          cp source, destination
        else
          raise "File exists at destination:  #{destination}"
        end # directory?
      else
        mkdir_p destination.parent unless destination.parent.exists?
        cp source, destination
      end # destination exists?
    end # Merge.cp_mkp

    # The keg_prefix and stash_root are expected to be Pathname objects.
    # The list members are just strings.
    def prep(keg_prefix, stash_root, list)
      list.each do |item|
        source = keg_prefix/item
        dest = stash_root/item
        cp_mkp source, dest
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
