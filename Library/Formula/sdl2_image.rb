class Sdl2Image < Formula
  desc 'Library for loading images as SDL surfaces and textures'
  homepage 'https://github.com/libsdl-org/SDL_image/'
  url 'https://github.com/libsdl-org/SDL_image/archive/refs/tags/release-2.0.1.tar.gz'
  sha256 '25b987b180ed75a809e14ddffc5122fa2bc4aaf7022fcae4ac0e566aefec8246'

  depends_on 'pkg-config' => :build
  depends_on 'sdl2'
  depends_on 'jpeg'    => :recommended
  depends_on 'libpng'  => :recommended
  depends_on 'libtiff' => :recommended
  depends_on 'webp'    => :recommended

  option :universal

  def install
    ENV.universal_binary if build.universal?
    inreplace 'SDL2_image.pc.in', '@prefix@', HOMEBREW_PREFIX

    args = [
      "--prefix=#{prefix}",
      '--disable-dependency-tracking',
      '--disable-silent-rules'
    ]
    args << '--disable-imageio' if MacOS.version < :snow_leopard


    system './configure', *args
    system 'make', 'install'
  end
end
