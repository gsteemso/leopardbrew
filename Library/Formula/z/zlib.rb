# stable release 2024-01-22; checked 2025-08-02
class Zlib < Formula
  desc "General-purpose lossless data-compression library"
  homepage "http://www.zlib.net/"
  url 'http://zlib.net/zlib-1.3.1.tar.xz'
  sha256 '38ef96b8dfe510d42707d9c781877914792541133e1870841463bfa73f883e32'

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
    for_archs './zpipe' do |_, cmd|
      Homebrew.system(*cmd) do
        $stdin.reopen('foo.txt')
        $stdout.reopen('foo.txt.z')
      end
      result = assert File.exists?('foo.txt.z')
      rm 'foo.txt.z'
      result
    end # for_archs |zpipe|
  end # test
end # Zlib
