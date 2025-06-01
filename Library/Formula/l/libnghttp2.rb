class Libnghttp2 < Formula
  desc 'HTTP/2 C Library'
  homepage 'https://nghttp2.org/'
  url 'https://github.com/nghttp2/nghttp2/releases/download/v1.65.0/nghttp2-1.65.0.tar.xz'
  sha256 'f1b9df5f02e9942b31247e3d415483553bc4ac501c87aa39340b6d19c92a9331'
  license 'MIT'

  head do
    url 'https://github.com/nghttp2/nghttp2.git', branch: 'master'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool' => :build
  end # head

  option :universal

  depends_on 'pkg-config' => :build

  # These used to live in `nghttp2`.
  link_overwrite 'include/nghttp2'
  link_overwrite 'lib/libnghttp2.a'
  link_overwrite 'lib/libnghttp2.dylib'
  link_overwrite 'lib/libnghttp2.14.dylib'
  link_overwrite 'lib/libnghttp2.so'
  link_overwrite 'lib/libnghttp2.so.14'
  link_overwrite 'lib/pkgconfig/libnghttp2.pc'

  def install
    ENV.universal_binary if build.universal?
    system 'autoreconf', '-ivf' if build.head?
    system './configure', "--prefix=#{prefix}",
                          '--disable-dependency-tracking',
                          '--disable-silent-rules',
                          '--enable-lib-only'
    cd 'lib' do
      system 'make'
      # `make check` does nothing
      system 'make', 'install'
    end # cd 'lib'
  end # install

  test do
    (testpath/'test.c').write <<-EOS.undent
      #include <nghttp2/nghttp2.h>
      #include <stdio.h>

      int main() {
        nghttp2_info *info = nghttp2_version(0);
        printf("%s", info->version_str);
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, 'test.c', "-I#{include}", "-L#{lib}", '-lnghttp2', '-o', 'test'
    for_archs('./test') { |_, cmd| assert_equal version.to_s, shell_output("#{cmd * ' '} ./test") }
  end # test
end # Libnghttp2
