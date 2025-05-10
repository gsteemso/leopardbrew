require 'merge'

class Openssl3 < Formula
  desc 'Cryptography and SSL/TLS Toolkit'
  homepage 'https://openssl.org/'
  url 'https://github.com/openssl/openssl/releases/download/openssl-3.5.0/openssl-3.5.0.tar.gz'
  sha256 '344d0a79f1a9b08029b0744e2cc401a43f9c90acd1044d09a530b4885a8e9fc0'
  license 'Apache-2.0'

  option :universal
  option 'without-tests', 'Skip the build‐time unit tests (not recommended on first install)'

  keg_only :provided_by_osx

  depends_on 'curl-ca-bundle'
  depends_on 'perl'

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
    # Leopard and newer have the crypto framework.
    ENV.append_to_cflags '-DOPENSSL_NO_APPLE_CRYPTO_RANDOM' if MacOS.version <= '10.5'
    # This could interfere with how we expect OpenSSL to build.
    ENV.delete('OPENSSL_LOCAL_CONFIG_DIR')
    # This ensures where Homebrew's Perl is needed the Cellar path isn't
    # hardcoded into OpenSSL's scripts, breaking them every Perl update.  Our
    # env does point to opt_bin, but by default OpenSSL resolves the symlink.
    ENV['PERL'] = Formula['perl'].opt_bin/'perl'

    if build.universal?
      archs = CPU.local_archs
      stashdir = buildpath/'arch-stashes'
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
        openssl/configuration.h
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
    ]
    args << 'sctp' if MacOS.version > :leopard  # pre‐Snow Leopard lacks these system headers
    args << 'enable-tfo' if MacOS.version >= :mojave  # pre-Mojave doesn’t support TCP Fast Open
    args << 'enable-brotli-dynamic' if enhanced_by? 'brotli'
    args << 'zlib-dynamic' if enhanced_by? 'zlib'
    args << 'enable-zstd-dynamic' if enhanced_by? 'zstd'
    # No {get,make,set}context support before Leopard
    args << 'no-async' if MacOS.version < :leopard

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.universal?

      arch_args = [
        arg_format(arch),
      ]
      arch_args << '-D__ILP32__' if Hardware::CPU.all_32b_archs.any? { |a| a == arch }

      # The assembly routines may still not work right on Tiger (needs to be
      # checked).  Out of the box, they are horked on 32‐bit G5s because Apple
      # never needed to define “__ILP32__” (see above).
      # → “no-asm” isn’t intended for production use.  Needs work.
      arch_args << 'no-asm' if MacOS.version < :leopard

      system 'perl', './Configure', *args, *arch_args
      system 'make'
      system 'make', 'test' if build.with? 'tests'
      system 'make', 'install', 'MANSUFFIX=ssl'

      if build.universal?
        system 'make', 'clean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        Merge.prep(include, stashdir/"h-#{arch}", the_headers)
      end # universal?
    end # each |arch|

    if build.universal?
      ENV.set_build_archs(archs)
      Merge.binaries(prefix, stashdir, archs)
      Merge.c_headers(include, stashdir, archs)
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
    for_archs bin/'openssl' do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s])
      system *arch_cmd, bin/'openssl', 'dgst', '-sha256', '-out', 'checksum.txt', 'testfile.txt'
      open('checksum.txt') do |f|
        checksum = f.read(100).split('=').last.strip
        assert_equal checksum, expected_checksum
      end
    end
  end # test
end # Openssl3
