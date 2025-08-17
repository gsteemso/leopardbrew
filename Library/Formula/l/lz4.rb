# stable release 2025-07-22; checked 2025-08-09
class Lz4 < Formula
  desc 'Lossless compression algorithm'
  homepage 'https://lz4.github.io/lz4'
  url 'https://github.com/lz4/lz4/archive/refs/tags/v1.10.0.tar.gz'
  sha256 '537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b'
  head 'https://github.com/lz4/lz4.git'

  option :universal

  def install
    ENV.enable_warnings if ENV.compiler == :gcc_4_0
    ENV.universal_binary if build.universal?

    system 'make', 'install', "PREFIX=#{prefix}"
  end

  test do
    input = 'testing compression and decompression'
    input_file = testpath/'in'
    input_file.write input
    output_file = testpath/'out'
    system 'sh', '-c', "cat\ #{input_file}\ |\ #{bin}/lz4\ |\ #{bin}/lz4\ -d\ >#{output_file}"
    assert_equal output_file.read, input
  end
end
