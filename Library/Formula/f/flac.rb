class Flac < Formula
  desc 'Free lossless audio codec'
  homepage 'https://xiph.org/flac/'
  url 'https://downloads.xiph.org/releases/flac/flac-1.4.3.tar.xz'
  sha256 '6c58e69cd22348f441b861092b825e591d0b822e106de6eb0ee4d05d27205b70'

  head do
    url 'https://git.xiph.org/flac.git'
    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end

  option :universal

  depends_on 'pkg-config' => :build
  depends_on 'libogg'     => :recommended

  fails_with :llvm do
    build 2326
    cause 'Undefined symbols when linking'
  end

  fails_with :clang do
    build 500
    cause 'Undefined symbols ___cpuid and ___cpuid_count'
  end

  def install
    ENV.universal_binary if build.universal?
    archs = Target.archset

    args = %W[
      --prefix=#{prefix}
      --disable-debug
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-static
    ]
    args << '--disable-asm-optimizations' if build.universal? or Target._32b?
    args << '--disable-64-bit-words' if Target._32b?
    args << '--without-ogg' if build.without? 'libogg'

    system './autogen.sh' if build.head?
    system './configure', *args

    # adds universal flags to the generated libtool script
    inreplace 'libtool' do |s|
      s.gsub! '\\$verstring ', "\\$verstring #{archs.as_arch_flags} "
    end

    system 'make', 'install'
  end

  test do
    raw_data = "pseudo audio data that stays the same \x00\xff\xda"
    (testpath/'in.raw').write raw_data
    # encode and decode
    system bin/'flac', '--endian=little', '--sign=signed', '--channels=1', '--bps=8', '--sample-rate=8000', '--output-name=in.flac', 'in.raw'
    system bin/'flac', '--decode', '--force-raw', '--endian=little', '--sign=signed', '--output-name=out.raw', 'in.flac'
    # diff input and output
    assert_equal `diff -q in.raw out.raw`, ''
  end
end
