class SocketWrapper < Formula
  desc 'Library passing all socket communications through unix sockets'
  homepage 'https://cwrap.org/socket_wrapper.html'
  url 'https://ftp.samba.org/pub/cwrap/socket_wrapper-1.5.0.tar.gz'
  version '1.5.0'
  sha256 '9c341f86c11b2738ee885cbf83b42ee4bd445ba96e57151b8ede12b9f54fd6f7'

  option :universal

  depends_on 'cmake'  => :build  # minimum version 3.10.0; ours is 3.9.6 due to old toolchain
  depends_on 'cmocka' => :build

  def install
    ENV.universal_binary if build.universal?
    system 'cmake', '.', '-DUNIT_TESTING=ON', *std_cmake_args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
  end # install

  test do
    system 'false'
  end
end # SocketWrapper
