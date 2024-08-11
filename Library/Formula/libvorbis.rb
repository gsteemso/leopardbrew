class Libvorbis < Formula
  desc 'Vorbis General Audio Compression Codec'
  homepage 'https://xiph.org/vorbis/'
  url 'https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz'
  sha256 'b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b'

  head do
    url 'http://svn.xiph.org/trunk/vorbis'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end

  option :universal

  depends_on 'pkg-config' => :build
  depends_on 'libogg'

  def install
    ENV.universal_binary if build.universal?

    system './autogen.sh' if build.head?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking'
    system 'make', 'install'
  end
end
