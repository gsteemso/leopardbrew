# This version is the last which will build on our ancient version of CMake (all the newer CMakes
# require C++11).
class Brotli < Formula
  desc 'Lossless streaming compression (see RFC 7932)'
  homepage 'https://brotli.org/'
  url 'https://github.com/google/brotli/archive/refs/tags/v1.0.9.tar.gz'
  sha256 'f9e8d81d0405ba66d181529af42a3354f838c939095ff99930da6aa9cdf6fe46'

  option :universal

  depends_on 'cmake' => :build

  def install
    archs = Target.archset
    mkdir 'build-dir' do
      system 'cmake', '-Wno-dev',
                      "-DCMAKE_OSX_ARCHITECTURES=#{archs.as_cmake_arch_flags}",
                      '-DCMAKE_BUILD_TYPE=Release',
                      "-DCMAKE_INSTALL_PREFIX=#{prefix}",
                      '..'
      system 'cmake', '--build', '.',
                      '--config', 'Release',
                      '--target', 'install'
    end
  end # install

  def caveats
    <<-_.undent
      Brotli bindings for Python 3 are available via Pip:
          pip3 install brotli
    _
  end if Formula['python3'].any_version_installed?

  test do
    system bin/'brotli', '-k', '-o', './brotliest.br', bin/'brotli'
    system bin/'brotli', '-t', 'brotliest.br'
    system bin/'brotli', '-d', 'brotliest.br'
    system 'diff', '-s', 'brotliest', bin/'brotli'
  end # test
end # Brotli
