class Opensp < Formula
  desc 'OpenSP:  Open SGML Parser'
  homepage 'http://www.openjade.org/'
  # “Audit” can whine about this URL all it wants, but the normal URL simply _is not there_.
  url 'https://sourceforge.net/projects/openjade/files/opensp/1.5.2/OpenSP-1.5.2.tar.gz/download'
  sha256 '57f4898498a368918b0d49c826aa434bb5b703d2c3b169beb348016ab25617ce'

  option :universal

  depends_on 'xmlto'  # for the documentation

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          "--mandir=#{man}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-http',
                          '--enable-xml-messages'
    system 'make'
    # do not run `make check` – 6 of the 20‐odd tests inexplicably fail since
    # 2005 and no one has bothered to figure out why
    system 'make', 'install'
  end # install
end # Opensp
