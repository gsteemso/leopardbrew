require 'merge'

class Openssl3 < Formula
  include Merge

  desc 'Cryptography and SSL/TLS Toolkit'
  homepage 'https://openssl.org/'
  url 'https://github.com/openssl/openssl/releases/download/openssl-3.3.2/openssl-3.3.2.tar.gz'
  sha256 '2e8a40b01979afe8be0bbfb3de5dc1c6709fedb46d6c89c10da114ab5fc3d281'
  license 'Apache-2.0'

  option :universal
  option 'without-tests', 'Skip the build‐time unit tests (not recommended)'

  depends_on 'curl-ca-bundle'
  depends_on 'perl'

  enhanced_by 'brotli'
  enhanced_by 'zlib'
  enhanced_by 'zstd'

  keg_only :provided_by_osx

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
    # This ensures where Homebrew's Perl is needed the Cellar path isn't
    # hardcoded into OpenSSL's scripts, breaking them every Perl update.  Our
    # env does point to opt_bin, but by default OpenSSL resolves the symlink.
    ENV['PERL'] = Formula['perl'].opt_bin/'perl'

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
      'no-legacy',  # for whatever reason, the build tests fail to locate the legacy provider
      'no-makedepend',
      'enable-trace',
      'zlib-dynamic'
    ]
    if MacOS.version < '10.5'
      args << 'no-async'                          # No {get,make,set}context support pre‐Leopard.
      args << '-DOPENSSL_NO_APPLE_CRYPTO_RANDOM'  # Leopard and newer have the crypto framework.
    end
    args << 'enable-brotli-dynamic' if enhanced_by? 'brotli'
    args << 'sctp' if MacOS.version > '10.5'  # Pre‐Snow Leopard lacks these system headers.
    args << 'enable-tfo' if MacOS.version >= '10.14'  # Pre-Mojave doesn’t support TCP Fast Open.
    args << 'enable-zstd-dynamic' if enhanced_by? 'zstd'

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.universal?

      arch_args = [
        arg_format(arch),
      ]
      arch_args << '-D__ILP32__' if CPU.is_32b_arch?(arch)  # Apple never needed to define this.

      # The assembly routines may still not work right on Tiger (needs checking).
      # → “no-asm” isn’t intended for production use.  This needs work either way.
      arch_args << 'no-asm' if MacOS.version < '10.5'

      system 'perl', './Configure', *args, *arch_args
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
