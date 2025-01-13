class Lzip < Formula
  desc "LZMA-based compression program similar to gzip or bzip2"
  homepage "http://www.nongnu.org/lzip/lzip.html"
  url 'http://download.savannah.gnu.org/releases/lzip/lzip-1.24.tar.gz'
  sha256 'd42659229b10e066eeb6e81eb673cdd893b672e512d26719c2d95975556ca56c'

  def install
    system "./configure", "--prefix=#{prefix}",
                          "CXX=#{ENV.cxx}",
                          "CXXFLAGS=#{ENV.cflags}"
    system "make", "check"
    ENV.deparallelize { system "make", "install" }
  end

  test do
    path = testpath/"data.txt"
    original_contents = "." * 1000
    path.write original_contents

    # compress: data.txt -> data.txt.lz
    system "#{bin}/lzip", path
    assert !path.exist?

    # decompress: data.txt.lz -> data.txt
    system "#{bin}/lzip", "-d", "#{path}.lz"
    assert_equal original_contents, path.read
  end
end
