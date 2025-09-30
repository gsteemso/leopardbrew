class ResolvWrapper < Formula
  desc 'wrapper library for DNS name resolving or DNS faking'
  homepage 'https://cwrap.org/resolv_wrapper.html'
  url 'https://ftp.samba.org/pub/cwrap/resolv_wrapper-1.1.8.tar.gz'
  version '1.1.8'
  sha256 'fbc30f77da3e12ecd4ef66ccf5ab77e0b744930ccd89062404082f928a8ec2e0'

  option :universal

  depends_on 'cmake'  => :build
  depends_on 'cmocka' => :build
  depends_on 'socket_wrapper'

  def install
    ENV.universal_binary if build.universal?
    system 'cmake', '.', '-DUNIT_TESTING=ON', *std_cmake_args
    system 'make'
    system 'make', 'test'
    system 'make', 'install'
  end # install
end # ResolvWrapper
