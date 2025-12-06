class Testdisk < Formula
  desc 'powerful free data-recovery utility'
  homepage 'http://www.cgsecurity.org/wiki/TestDisk'
  url 'http://www.cgsecurity.org/testdisk-7.2.tar.bz2'
  sha256 'f8343be20cb4001c5d91a2e3bcd918398f00ae6d8310894a5a9f2feb813c283f'

  def install
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make', 'install'
  end # install

  test do
    path = 'test.dmg'
    system 'hdiutil', 'create', '-megabytes', '10', path
    system bin/'testdisk', '/list', path
  end
end # Testdisk
