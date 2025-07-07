class Ffmpeg < Formula
  desc 'Play, record, convert, and stream audio and video'
  homepage 'https://ffmpeg.org/'
  url 'https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz'
  sha256 '733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1'
  head 'https://github.com/FFmpeg/FFmpeg.git'

  needs :c11, :cxx11

  option 'without-lame', 'Disable MP3 encoder'
  option 'without-x264', 'Disable H.264 encoder'

  option 'with-drawtext', 'Enable “drawtext” filter'
  option 'with-libssh',   'Enable SFTP support'
  option 'with-rtmpdump', 'Enable streaming Flash support'
  option 'with-webp',     'Enable WebP support'

  option 'with-ssl=',   'Force selection of “gnutls” vs. “libressl” vs. “openssl”'

  # Tiger's ld doesn't like -install_name
  depends_on :ld64
  # Tiger's make is too old
  depends_on 'make' => :build if MacOS.version < :leopard
  depends_on 'pkg-config' => :build
  case CPU.type
    when :intel   then depends_on 'yasm'             => :build
    when :powerpc then depends_on 'gas-preprocessor' => :build
  end

  the_ssl = case ARGV.value('with-ssl')
      when %r{^gnutls} then 'gnutls'
      when %r{^libressl} then 'libressl'
      when %r{^openssl} then 'openssl3'
      else if Formula['openssl3'].installed? then 'openssl3'
        elsif Formula[ 'gnutls' ].installed? then 'gnutls'
        elsif Formula['libressl'].installed? then 'libressl'
        end
    end

  depends_on the_ssl if the_ssl

  depends_on 'x264' => :recommended
  depends_on 'lame' => :recommended

  depends_group ['drawtext', ['fontconfig', 'freetype', 'fribidi', 'harfbuzz'] => :optional]
  depends_on 'libssh'   => :optional
  depends_on 'rtmpdump' => :optional
  depends_on 'webp'     => :optional

  def install
    args = %W[--prefix=#{prefix}
              --enable-gpl
              --enable-version3
              --enable-shared
              --enable-gray
              --enable-opencl
              --enable-opengl
              --cc=#{ENV.cc}
              --enable-pic
              --enable-hardcoded-tables
            ]

    case the_ssl
      when 'gnutls'   then args << '--enable-gnutls'
      when 'libressl' then args << '--enable-libressl'
      when 'openssl3' then args << '--enable-openssl'
    end

    args << '' # if MacOS.version > :lion

    args << '--enable-libmp3lame' if build.with? 'lame'
    args << '--enable-libx264'    if build.with? 'x264'

    args << '--enable-libfontconfig' << '--enable-libfreetype' \
         << '--enable-libfribidi'    << '--enable-libharfbuzz' if build.with? 'drawtext'
    args << '--enable-libssh'  if build.with? 'libssh'
    args << '--enable-librtmp' if build.with? 'rtmpdump'
    args << '--enable-libwebp' if build.with? 'webp'

#    args << "--disable-asm" if MacOS.version < :leopard
#    args << "--disable-altivec" if !Hardware::CPU.altivec? || (build.bottle? && ARGV.bottle_arch == :g3)

    # These librares are GPL-incompatible, and require ffmpeg be built with
    # the "--enable-nonfree" flag, which produces unredistributable libraries
#    if %w[faac fdk-aac openssl].any? { |f| build.with? f }
#      args << "--enable-nonfree"
#    end

    system "./configure", *args

    system make
    system make, 'install'
  end # install

  test do
    # Create an example mp4 file
    system "#{bin}/ffmpeg", "-y", "-filter_complex",
        "testsrc=rate=1:duration=1", "#{testpath}/video.mp4"
    assert (testpath/"video.mp4").exist?
  end # do test
end # Ffmpeg
