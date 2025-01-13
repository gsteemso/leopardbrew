class Zlib < Formula
  desc "General-purpose lossless data-compression library"
  homepage "http://www.zlib.net/"
  url "https://zlib.net/fossils/zlib-1.3.1.tar.gz"
  sha256 "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"

  bottle do
    cellar :any
    sha256 "0ec484b96d45d53be8501f85f4b81b2ac2d70d84fd5d1602ece4668d570b05af" => :tiger_altivec
  end

  option :universal

  keg_only :provided_by_osx

  # http://zlib.net/zlib_how.html
  resource "test_artifact" do
    url "http://zlib.net/zpipe.c"
    version "20051211"
    sha256 "68140a82582ede938159630bca0fb13a93b4bf1cb2e85b08943c26242cf8f3a6"
  end

  def install
    ENV.universal_binary if build.universal?

    # The configure test for whether shared libraries are supported involves
    # invoking gcc -w.  On failure it falls back to building a static library.
    ENV.enable_warnings if ENV.compiler == :gcc_4_0
    system "./configure", "--prefix=#{prefix}"
    system "make", "install"
  end # install

  test do
    testpath.install resource('test_artifact')
    ENV.universal_binary if build.universal?
    system ENV.cc, 'zpipe.c', "-I#{include}", "-L#{lib}", '-lz', '-o', 'zpipe'
    touch 'foo.txt'
    for_archs './zpipe' do |a|
      arch_cmd = (a.nil? ? '' : "arch -arch #{a.to_s} ")
      system "#{arch_cmd}./zpipe < foo.txt > foo.txt.z"
      assert File.exists?('foo.txt.z')
      rm 'foo.txt.z'
    end
  end # test
end # Zlib
