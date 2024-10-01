class Webp < Formula
  desc 'Image format providing lossless and lossy compression for web images'
  homepage 'https://developers.google.com/speed/webp/'
  url 'https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.4.0.tar.gz'
  sha256 '61f873ec69e3be1b99535634340d5bde750b2e4447caa1db9f61be3fd49ab1e5'
  license 'BSD-3-Clause'

  head do
    url 'https://chromium.googlesource.com/webm/libwebp.git'
    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end

  option :universal

  depends_on 'giflib'
  depends_on 'jpeg'
  depends_on 'libpng'
  depends_on 'libtiff'
  depends_on 'sdl2'

  def install
    system './autogen.sh' if build.head?

    ENV.universal_binary if build.universal?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-everything',
                          '--enable-swap-16bit-csp'
    system 'make', 'install'
  end

  test do
    system bin/'cwebp', '-lossless', '-mt', test_fixtures('test.png'), '-o', 'webp_test.webp'
    system bin/'dwebp', '-mt', 'webp_test.webp', '-o', 'webp_test.png'
    assert File.exists?('webp_test.webp') and File.exists?('webp_test.png')
  end
end
