class Libtiff < Formula
  desc 'TIFF library and utilities'
  homepage 'https://libtiff.gitlab.io/libtiff/'
  url 'https://download.osgeo.org/libtiff/tiff-4.7.0.tar.xz'
  sha256 '273a0a73b1f0bed640afee4a5df0337357ced5b53d3d5d1c405b936501f71017'

  option :universal
  option 'without-tests', 'Skip the build‐time unit tests'

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
    begin
      safe_system 'make', '-C', 'test', 'check'
    rescue ErrorDuringExecution
      opoo 'Some of the unit tests did not complete successfully.',
        'This is not unusual.  If you ran Leopardbrew in “verbose” mode, the fraction of',
        'tests which failed will be visible in the text above; only you can say whether',
        'the pass rate shown there counts as “good enough”.'
    end if build.with? 'tests'
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
    for_archs bin/'tiffdump' do |_, cmd|
      system *cmd[0..-2], './test', 'test.tif'
      result = assert_match /ImageWidth.*10/, shell_output("#{cmd * ' '} test.tif")
      rm './test.tif'
      result
    end
  end # test
end # Libtiff
