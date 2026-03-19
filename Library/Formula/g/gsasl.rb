# Stable release 2025-03-30; checked 2026-03-14.
class Gsasl < Formula
  desc 'Simple Authentication and Security Layer library command-line interface'
  homepage 'https://www.gnu.org/software/gsasl/'
  url 'http://ftpmirror.gnu.org/gsasl/gsasl-2.2.2.tar.gz'
  mirror 'https://ftp.gnu.org/gsasl/gsasl-2.2.2.tar.gz'
  sha256 '41e8e442648eccaf6459d9ad93d4b18530b96c8eaf50e3f342532ef275eff3ba'

  option :universal

  option 'with-gnutls',  'Build with STARTTLS support'
  option 'with-libntlm', 'Interoperate with some versions of Windows'

  depends_on 'pkg-config' => :build
  depends_on 'libidn'
  depends_on :nls
  depends_on 'gnutls'  => :optional
  depends_on 'libntlm' => :optional
  depends_on 'openssl3' if build.without? 'gnutls'

  def install
    ENV.universal_binary if build.universal?

    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking',
      '--with-gssapi-impl=mit'
    ]
    args << '--with-openssl=auto' if build.without? 'gnutls'

    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end # install

  test do
    assert_match /#{version}/, shell_output("#{bin}/gsasl -V")
  end
end # Gsasl
