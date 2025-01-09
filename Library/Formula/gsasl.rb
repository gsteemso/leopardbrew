class Gsasl < Formula
  desc 'Simple Authentication and Security Layer library command-line interface'
  homepage 'https://www.gnu.org/software/gsasl/'
  url 'http://ftpmirror.gnu.org/gsasl/gsasl-2.2.1.tar.gz'
  mirror 'https://ftp.gnu.org/gsasl/gsasl-2.2.1.tar.gz'
  sha256 'd45b562e13bd13b9fc20b372f4b53269740cf6279f836f09ce11b9d32bcee075'

  option :universal

  option 'with-gnutls',  'Build with STARTTLS support'
  option 'with-libntlm', 'Interoperate with some versions of Windows'

  depends_on 'gnutls'  => :optional
  depends_on 'libntlm' => :optional
  depends_on 'gettext'
  depends_on 'libidn'
  depends_on 'openssl3' if build.without? 'gnutls'
  depends_on 'pkg-config' => :build

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
  end # test
end # Gsasl
