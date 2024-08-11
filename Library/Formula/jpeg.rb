class Jpeg < Formula
  desc 'JPEG image manipulation library'
  homepage 'http://www.ijg.org'
  url 'http://www.ijg.org/files/jpegsrc.v9f.tar.gz'
  sha256 '04705c110cb2469caa79fb71fba3d7bf834914706e9641a4589485c1f832565b'

  option :universal

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking'
    system 'make', 'install'
  end

  test do
    system "#{bin}/djpeg", test_fixtures('test.jpg')
  end
end
