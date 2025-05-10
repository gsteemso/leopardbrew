class Openldap < Formula
  desc 'Lightweight Directory Access Protocol version 3 server and client'
  homepage 'https://openldap.org/'
  url 'https://openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.8.tgz'
  version '2.6.8'
  sha256 '48969323e94e3be3b03c6a132942dcba7ef8d545f2ad35401709019f696c3c4e'

  def install
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make'
    system 'make', 'install'
  end

  test do
    system 'false'
  end
end # Openldap
