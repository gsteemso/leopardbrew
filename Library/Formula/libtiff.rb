class Libtiff < Formula
  desc 'TIFF library and utilities'
  homepage 'https://libtiff.gitlab.io/libtiff/'
  url 'https://download.osgeo.org/libtiff/tiff-4.6.0.tar.xz'
  sha256 'e178649607d1e22b51cf361dd20a3753f244f022eefab1f2f218fc62ebaf87d2'

  bottle do
    sha256 'bb0a906ad2162c37c63d8222584cec44e712b5478d7a45d931f6782bcc05f695' => :tiger_altivec
  end

  option :universal

  depends_on 'python3' => :build  # for the documentation
  depends_on 'jpeg'
  depends_on 'xz'
  depends_on 'zlib'
  depends_on 'zstd' => :recommended

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}", '--disable-dependency-tracking'
    system 'make', 'install'
  end

  def caveats; <<-_.undent
    LibTIFF will take advantage of WebP, if WebP is already present when LibTIFF
    is brewed.  WebP cannot be automatically brewed as a dependency because WebP
    already depends on LibTIFF.
  _
  end

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <tiffio.h>

      int main(int argc, char* argv[])
      {
        TIFF *out = TIFFOpen(argv[1], "w");
        TIFFSetField(out, TIFFTAG_IMAGEWIDTH, (uint32) 10);
        TIFFClose(out);
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, 'test.c', "-L#{lib}", '-ltiff', '-o', 'test'
    system './test', 'test.tif'
    assert_match /ImageWidth.*10/, shell_output("#{bin}/tiffdump test.tif")
  end
end
