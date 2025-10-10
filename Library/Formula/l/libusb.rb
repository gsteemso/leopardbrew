class Libusb < Formula
  desc 'Cross‐platform library for USB device access'
  homepage 'https://libusb.info/'
  url 'https://github.com/libusb/libusb/releases/download/v1.0.27/libusb-1.0.27.tar.bz2'
  sha256 'ffaa41d741a8a3bee244ac8e54a72ea05bf2879663c098c82fc5757853441575'
  license 'LGPL-2.1-or-later'

  head do
    url 'https://github.com/libusb/libusb.git', branch: 'master'
    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end

  option :universal

  needs :c11

  def install
    ENV.universal_binary if build.universal?
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-system-log
      --enable-tests-build
    ]
    system './autogen.sh' if build.head?
    system './configure', *args
    system 'make'
    system 'make', 'check'
    system 'make', 'install'
    (pkgshare/'examples').install Dir['examples/*'] - Dir['examples/Makefile*']
  end

  test do
    cp_r (pkgshare/'examples'), testpath
    cd 'examples' do
      system ENV.cc, 'listdevs.c', "-L#{lib}", "-I#{include}/libusb-1.0",
             '-lusb-1.0', '-o', 'test'
      system './test'
    end
  end
end
