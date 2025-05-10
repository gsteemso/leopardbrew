class KerberosV5 < Formula
  desc 'MIT’s implementation of Kerberos version 5 authentication'
  homepage 'https://kerberos.org/'
  url 'https://kerberos.org/dist/krb5/1.21/krb5-1.21.3.tar.gz'
  version '1.21.3'
  sha256 'b7a4cd5ead67fb08b980b21abd150ff7217e85ea320c9ed0c6dadd304840ad35'

  option :universal

  keg_only :provided_by_osx

  resource 'macos_extras_panther' do
    url 'http://web.mit.edu/macdev/Download/Mac_OS_X_10.3_Kerberos_Extras.dmg'
    sha256 ''
  end

  resource 'macos_extras_tiger_snowleopard' do
    url 'http://web.mit.edu/macdev/Download/Mac_OS_X_10.4_10.6_Kerberos_Extras.dmg'
    sha256 ''
  end

  def install
    ENV.universal_binary if build.universal?

    system './configure', "prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make'
    system 'make', 'install'
  end

  test do
    system 'false'
  end
end # KerberosV5
