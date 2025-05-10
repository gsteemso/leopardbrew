class Libogg < Formula
  desc 'Ogg Bitstream Library'
  homepage 'https://www.xiph.org/ogg/'
  url 'http://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.xz'
  sha256 'c4d91be36fc8e54deae7575241e03f4211eb102afb3fc0775fbbc1b740016705'

  head do
    url 'https://svn.xiph.org/trunk/ogg'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end

  option :universal

  def install
    ENV.universal_binary if build.universal?

    system './autogen.sh' if build.head?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-maintainer-mode',
                          '--disable-silent-rules'
    system 'make'
    ENV.deparallelize { system 'make', 'install' }
  end
end
