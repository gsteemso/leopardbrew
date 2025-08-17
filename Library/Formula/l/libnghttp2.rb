# stable release 2025-06-17; checked 2025-08-06
class Libnghttp2 < Formula
  desc 'HTTP/2 C Library'
  homepage 'https://nghttp2.org/'
  url 'https://github.com/nghttp2/nghttp2/releases/download/v1.66.0/nghttp2-1.66.0.tar.xz'
  sha256 '00ba1bdf0ba2c74b2a4fe6c8b1069dc9d82f82608af24442d430df97c6f9e631'
  license 'MIT'

  head do
    url 'https://github.com/nghttp2/nghttp2.git', branch: 'master'

    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
  end # head

  option :universal
  # Can’t do an option to build the apps, as they require C++11 (or possibly C++20, hard to tell).

  depends_on 'pkg-config' => :build
  enhanced_by 'python3'

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

    args = %W[
        --prefix=#{prefix}
        --disable-dependency-tracking
        --disable-silent-rules
        --enable-lib-only
      ]
    ENV['PYTHON'] = "#{Formula['python3'].bin}/python3" \
                                  if enhanced_by? 'python3'

    system './configure', *args
    cd 'lib' do
      system 'make'
      # `make check` does nothing
      system 'make', 'install'
    end
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
