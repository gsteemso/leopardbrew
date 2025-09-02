# stable release 2025-08-05; checked 2025-08-07
require 'merge'

class Openssl3 < Formula
  include Merge

  desc 'Cryptography and SSL/TLS Toolkit'
  homepage 'https://openssl-library.org/'
  url 'https://github.com/openssl/openssl/releases/download/openssl-3.5.2/openssl-3.5.2.tar.gz'
  sha256 'c53a47e5e441c930c3928cf7bf6fb00e5d129b630e0aa873b08258656e7345ec'
  license 'Apache-2.0'

  keg_only :provided_by_osx

  option :universal
  option 'without-tests', 'Skip the build‐time unit tests (not recommended on the first install)'

  depends_on :macos => :tiger  # Panther doesn’t declare the right “timezone” in <time.h>.

  depends_on 'curl-ca-bundle'
  depends_on 'perl'

  # These are loaded dynamically by OpenSSL at runtime, so don’t be alarmed that they do not appear
  # in the libraries’ linkage lists even when enhancement has been performed.
  enhanced_by 'brotli'
  enhanced_by 'zlib'
  enhanced_by 'zstd'

  def arg_format(arch)
    case arch
      when :arm64  then 'darwin64-arm64'
      when :i386   then 'darwin-i386'
      when :ppc    then 'darwin-ppc'
      when :ppc64  then 'darwin64-ppc'
      when :x86_64 then 'darwin64-x86_64'
    end
  end

  def install
    # Build breaks passing -w.
    ENV.enable_warnings if ENV.compiler == :gcc_4_0
    # This could interfere with how we expect OpenSSL to build.
    ENV.delete('OPENSSL_LOCAL_CONFIG_DIR')
    # This ensures where Homebrew’s Perl is needed its Cellar path isn’t hardcoded into OpenSSL’s
    # scripts, breaking them every Perl update.  Our env does point to opt_bin, but by default
    # OpenSSL resolves the symlink.
    ENV['HASHBANGPERL'] = Formula['perl'].opt_bin/'perl'

    if build.universal?
      archs = CPU.local_archs
      the_binaries = %w[
        bin/openssl
        lib/engines-3/capi.dylib
        lib/engines-3/loader_attic.dylib
        lib/engines-3/padlock.dylib
        lib/libcrypto.3.dylib
        lib/libcrypto.a
        lib/libssl.3.dylib
        lib/libssl.a
      ]
      the_headers = %w[
        include/openssl/configuration.h
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    openssldir.mkpath

    args = [
      "--prefix=#{prefix}",
      "--openssldir=#{openssldir}",
      'no-legacy',      # For whatever reason, the build tests fail to locate the legacy provider.
      'no-makedepend',  # Required for multi-architecture builds.
      'enable-pie',
      'enable-trace',
      'enable-zlib-dynamic'
    ]
    if MacOS.version < :leopard
      args += ['no-async',          # There’s no {get,make,set}context support pre‐Leopard.
               '-DOPENSSL_NO_APPLE_CRYPTO_RANDOM',  # Nor the crypto framework.
               '-D__DARWIN_UNIX03'  # If this is not set, 'timezone' is a pointer to characters
        ]                           # instead of a longint, making a mess in crypto/asn1/a_time.c.
    end
    args << 'sctp'       if MacOS.version >  :leopard  # Pre‐Snow Leopard lacks these system headers.
    args << 'enable-tfo' if MacOS.version >= :mojave   # Pre-Mojave doesn’t support TCP Fast Open.
    if enhanced_by? 'brotli'
      brotli = Formula['brotli']
      args += ['enable-brotli-dynamic',
               "--with-brotli-include=#{brotli.opt_include}",
               "--with-brotli-lib=#{brotli.opt_lib}"
        ]
    end
    if enhanced_by? 'zlib'
      zlib = Formula['zlib']
      args += ["--with-zlib-include=#{zlib.opt_include}", "--with-zlib-lib=#{zlib.opt_lib}"]
    else
      args += ['--with-zlib-include=/usr/include', '--with-zlib-lib=/usr/lib']
    end
    if enhanced_by? 'zstd'
      zstd = Formula['zstd']
      args += ['enable-zstd-dynamic',
               "--with-zstd-include=#{zstd.opt_include}",
               "--with-zstd-lib=#{zstd.opt_lib}"
        ]
    end

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.universal?

      arch_args = [
        arg_format(arch),
      ]
      arch_args << '-D__ILP32__' if CPU.32b_arch?(arch)  # Apple never needed to define this.

      # “perl Configure”, instead of “./Configure”, because the Configure script’s shebang line may
      # well name the wrong Perl binary.  (If we have an outdated stock Perl, we really do not want
      # to use that when we meant to use brewed Perl.)
      system 'perl', 'Configure', *args, *arch_args
      system 'make'
      system 'make', 'test' if build.with? 'tests'
      system 'make', 'install'

      if build.universal?
        system 'make', 'clean'
        merge_prep(:binary, arch, the_binaries)
        merge_prep(:header, arch, the_headers)
      end # universal?
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      merge_binaries(archs)
      merge_c_headers(archs)
    end # universal?
  end # install

  def openssldir
    etc/'openssl@3'
  end

  def post_install
    rm_f openssldir/'cert.pem'
    openssldir.install_symlink Formula['curl-ca-bundle'].opt_share/'ca-bundle.crt' => 'cert.pem'
  end

  def caveats
    <<-EOS.undent
      A CA file is provided by the `curl-ca-bundle` formula.  To add certificates to
      it, place .pem files in
        #{openssldir}/certs
      and run
        #{opt_bin}/c_rehash
    EOS
  end

  test do
    # Make sure the necessary .cnf file exists, otherwise OpenSSL gets moody.
    assert_predicate openssldir/'openssl.cnf', :exist?,
            'OpenSSL requires the .cnf file for some functionality'

    # Check OpenSSL itself functions as expected.
    (testpath/'testfile.txt').write('This is a test file')
    expected_checksum = 'e2d0fe1585a63ec6009c8016ff8dda8b17719a637405a4e23c0ff81339148249'
    for_archs bin/'openssl' do |_, cmd|
      system *cmd, 'dgst', '-sha256', '-out', 'checksum.txt', 'testfile.txt'
      open('checksum.txt') do |f|
        checksum = f.read(100).split('=').last.strip
        assert_equal checksum, expected_checksum
      end
    end # for_archs |openssl|
  end # test
end # Openssl3
