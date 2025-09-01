# stable release 2017-08-10; checked 2025-08-16
class Lzop < Formula
  desc 'High-speed file compressor'
  homepage 'https://www.lzop.org/'
  url 'https://www.lzop.org/download/lzop-1.04.tar.gz'
  sha256 '7e72b62a8a60aff5200a047eea0773a8fb205caf7acbe1774d95147f305a2f41'

  depends_on 'lzo'

  def install
    system './configure', "--prefix=#{prefix}", '--disable-dependency-tracking'
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    path = testpath/'test'
    text = 'This is Leopardbrew'
    path.write text

    system "#{bin}/lzop", 'test'
    assert File.exists?('test.lzo')
    rm path

    system "#{bin}/lzop", '-d', 'test.lzo'
    assert_equal text, path.read
  end
end
