#stable release 2025-12-24; checked 2026-03-21.
class Vice < Formula
  desc 'Versatile Commodore Emulator'
  homepage 'https://vice-emu.sourceforge.io/'
  url 'https://sourceforge.net/projects/vice-emu/files/releases/vice-3.10.tar.gz'
  sha256 '8e5bac18cbcb9f192380ad3ef881f8790f5b75c41d7b3da65d831985d864d6d1'

  needs :cxx11

  depends_on 'autoconf'
  depends_on 'automake'
  depends_on 'dos2unix'
  depends_on 'lame'
  depends_on 'libomp'
  depends_on 'libpng'
  depends_on 'pkg-config'
  depends_on 'sdl'
  depends_on 'sdl-image'
  depends_on 'texinfo'
  depends_on 'xa'

  def install
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          "--enable-macos-minimum-version=#{MacOS.version}"
                          '--enable-sdl1ui',
                          '--enable-platformdox'
    system 'make'
    system 'make', 'bindist'
  end
end # Vice
