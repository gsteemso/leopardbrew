# Upstream project has requested we use a mirror as the main URL
# https://github.com/Homebrew/homebrew/pull/21419
class Xz < Formula
  desc 'General-purpose data compression with high compression ratio'
  homepage 'http://tukaani.org/xz/'
  url 'https://fossies.org/linux/misc/xz-5.6.2.tar.bz2'
  mirror 'https://github.com/tukaani-project/xz/releases/download/v5.6.2/xz-5.6.2.tar.bz2'
  sha256 'e12aa03cbd200597bd4ce11d97be2d09a6e6d39a9311ce72c91ac7deacde3171'
  version '5.6.2p1'

  option :universal

  patch do
    url 'https://github.com/tukaani-project/xz/releases/download/v5.6.2/xz-5213-547-562-libtool.patch'
    sha256 '31f58851acdf0d24d15bce14782dafa5a447ee922eaa39859170277dc9a8fae7'
  end

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

    # compress: data.txt -> data.txt.xz
    system bin/'xz', path
    assert !path.exist?

    # decompress: data.txt.xz -> data.txt
    system bin/'xz', '-d', "#{path}.xz"
    assert_equal original_contents, path.read
  end # test
end # Xz
