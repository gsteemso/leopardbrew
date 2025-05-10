class Libpsl < Formula
  desc 'C library for the Public Suffix List'
  homepage 'https://rockdaboot.github.io/libpsl'
  url 'https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.lz'
  sha256 '9a9f6a8c6edba650cf9ea55475cd172dd28487316804e9c73202d97572cd3a2d'

  depends_on 'libidn2'
  depends_on 'libunistring'
  depends_on :python3 => :build

  def install
    ENV.universal_binary

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --disable-gtk-doc
      --enable-man
      --enable-builtin
    ]

    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    system 'psl', '--version'
    system 'psl', '--print-info'
    system 'psl', '--print-unreg-domain', '.ci.stanwood.wa.us'
  end
end
