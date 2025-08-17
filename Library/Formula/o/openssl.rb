# stable release 2023-09-12; discontinued
require 'merge'

class Openssl < Formula
  include Merge

  desc 'SSL/TLS cryptography library'
  homepage 'https://openssl.org/'
  url 'https://www.openssl.org/source/openssl-1.1.1w.tar.gz'
  mirror 'https://www.mirrorservice.org/sites/ftp.openssl.org/source/openssl-1.1.1w.tar.gz'
  sha256 'cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8'

  bottle do
    sha256 '7fa8eeb679ec9e180c5296515c1402207c653b6fd22be981b1c67e81f3fc0c4b' => :tiger_altivec
  end

  option :universal
  option 'without-tests', 'Skip the build-time unit tests (not recommended)'

  depends_on 'curl-ca-bundle'
  # Need a minimum of Perl 5.10 for Configure script and Test::More 0.96 for testsuite
  depends_on 'perl' => :build

  keg_only :provided_by_osx

  def openssldir; etc/'openssl'; end

  def arg_xlate(arch)
    case arch
      when :i386   then 'darwin-i386-cc'
      when :ppc    then 'darwin-ppc-cc'
      when :ppc64  then 'darwin64-ppc-cc'
      when :x86_64 then 'darwin64-x86_64-cc'
    end
  end

  def install
    # Build breaks passing -w
    ENV.enable_warnings if ENV.compiler == :gcc_4_0
    # This ensures where Homebrew's Perl is needed the Cellar path isn't
    # hardcoded into OpenSSL's scripts, breaking them every Perl update.  Our
    # env does point to opt_bin, but by default OpenSSL resolves the symlink.
    ENV['PERL'] = Formula['perl'].opt_bin/'perl'
#    # OpenSSL will prefer the PERL environment variable if set over $PATH
#    # which can cause some odd edge cases & isn't intended. Unset for safety.
#    ENV.delete('PERL')
    ENV.deparallelize

    if build.universal?
      archs = CPU.local_archs
      the_binaries = %w[
        bin/openssl
        lib/libcrypto.a
        lib/libcrypto.1.1.dylib
        lib/libssl.a
        lib/libssl.1.1.dylib
        lib/engines-1.1/capi.dylib
        lib/engines-1.1/padlock.dylib
      ]
      the_headers = %w[
        include/openssl/opensslconf.h
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    openssldir.mkpath

    # SSLv2 died with 1.1.0, so no-ssl2 is no longer required.
    # SSLv3 & zlib are off by default since 1.1.0 but this may not be obvious to everyone,
    # so explicitly state it for now to help debug inevitable breakage.
    args = %W[
      --prefix=#{prefix}
      --openssldir=#{openssldir}
      no-ssl3
      no-ssl3-method
      no-zlib
      shared
      enable-cms
      threads
    ]
    if MacOS.version < :leopard
      args << 'no-async'                          # No {get,make,set}context support before Leopard
      args << '-DOPENSSL_NO_APPLE_CRYPTO_RANDOM'  # Leopard and newer have the crypto framework
    end

    archs.each do |arch|
      ENV.set_build_archs(arch) if build.universal?

      system 'perl', './Configure', *args, arg_xlate(arch)
      system 'make'
      system 'make', 'test' if build.with?('tests')
      system 'make', 'install', "MANDIR=#{man}", 'MANSUFFIX=ssl'

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

  def post_install
    if MacOS.version <= :leopard
      rm_rf openssldir/'cert.pem'
      openssldir.install_symlink Formula['curl-ca-bundle'].opt_share/'ca-bundle.crt' => 'cert.pem'
    else  # Mac OS > leopard
      keychains = %w[
          /Library/Keychains/System.keychain
          /System/Library/Keychains/SystemRootCertificates.keychain
        ]
      certs_list = `security find-certificate -a -p #{keychains.join(' ')}`
      certs = certs_list.scan %r{-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----}m
      valid_certs = certs.select do |cert|
        IO.popen("#{bin}/openssl x509 -inform pem -checkend 0 -noout", 'w') do |openssl_io|
          openssl_io.write(cert)
          openssl_io.close_write
        end
        $?.success?
      end # select |cert|
      openssldir.mkpath
      (openssldir/'cert.pem').atomic_write(valid_certs.join("\n"))
    end # post-leopard
  end # post_install

  def caveats; <<-EOS.undent
      A CA file has been bootstrapped using certificates from the SystemRoots
      keychain. To add additional certificates (e.g. the certificates added in
      the System keychain), place .pem files in
          #{openssldir}/certs
      and run
          #{opt_bin}/c_rehash
    EOS
  end

  test do
    # Make sure the necessary .cnf file exists, otherwise OpenSSL gets moody.
    cnf_path = openssldir/'openssl.cnf'
    assert cnf_path.exist?, 'OpenSSL requires the .cnf file for some functionality'

    # Check OpenSSL itself functions as expected.
    (testpath/'testfile.txt').write('This is a test file')
    expected_checksum = 'e2d0fe1585a63ec6009c8016ff8dda8b17719a637405a4e23c0ff81339148249'
    for_archs "#{bin}/openssl" do |_, cmd|
      system *cmd, 'dgst', '-sha256', '-out', 'checksum.txt', 'testfile.txt'
      open('checksum.txt') do |f|
        checksum = f.read(100).split('=').last.strip
        assert_equal checksum, expected_checksum
      end
    end # each arch |a|
  end # test
end # Openssl
