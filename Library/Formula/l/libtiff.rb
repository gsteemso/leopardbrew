class Libtiff < Formula
  desc 'TIFF library and utilities'
  homepage 'https://libtiff.gitlab.io/libtiff/'
  url 'https://download.osgeo.org/libtiff/tiff-4.7.0.tar.xz'
  sha256 '273a0a73b1f0bed640afee4a5df0337357ced5b53d3d5d1c405b936501f71017'

  option :universal

  depends_on 'python3' => :build  # for the documentation
  depends_on 'jbigkit'
  depends_on 'jpeg'
  depends_on 'libdeflate'
  depends_on 'xz'
  depends_on 'zlib'
  depends_on 'zstd'

  enhanced_by 'webp'

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-cxx',
                          '--enable-defer-strile-load',
                          '--enable-deprecated',  # symbol versioning is off; soften the blow
                          '--with-x'
    system 'make'
    bombproof_system 'make', '-C', 'test', 'check'
    system 'make', 'install'
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
    system ENV.cc, 'test.c', "-L#{lib}", '-ltiff', '-o', 'test'
    for_archs './test' do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s])
      system *arch_cmd, './test', 'test.tif'
      assert_match /ImageWidth.*10/, shell_output("#{arch_cmd * ' '} #{bin}/tiffdump test.tif")
      rm './test.tif'
    end
  end # test
end # Libtiff
