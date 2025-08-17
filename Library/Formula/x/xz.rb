# stable release 2025-04-03; checked 2025-08-01
class Xz < Formula
  desc 'General-purpose data compression with high compression ratio'
  homepage 'http://tukaani.org/xz/'
  url 'https://github.com/tukaani-project/xz/releases/download/v5.8.1/xz-5.8.1.tar.bz2'
  sha256 '5965c692c4c8800cd4b33ce6d0f6ac9ac9d6ab227b17c512b6561bce4f08d47e'

  option :universal

  enhanced_by :nls

  def install
    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-debug',
                          '--disable-dependency-tracking',
                          '--disable-silent-rules'
    system 'make', 'install'
  end # install

  test do
    path = testpath/'data.txt'
    original_contents = '.' * 1000
    path.write original_contents

    for_archs bin/'xz' do |_, cmd|
      # compress: data.txt -> data.txt.xz
      system *cmd, path
      assert !path.exists?

      # decompress: data.txt.xz -> data.txt
      system *cmd, '-d', "#{path}.xz"
      assert_equal original_contents, path.read
    end # for_archs |xz|
  end # test
end # Xz
