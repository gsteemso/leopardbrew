class Libnghttp2 < Formula
  desc 'HTTP/2 C Library'
  homepage 'https://nghttp2.org/'
  url 'https://github.com/nghttp2/nghttp2/releases/download/v1.62.0/nghttp2-1.62.1.tar.xz'
  mirror 'http://fresh-center.net/linux/www/nghttp2-1.62.1.tar.xz'
  sha256 '2345d4dc136fda28ce243e0bb21f2e7e8ef6293d62c799abbf6f633a6887af72'
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

  # Apple GCC thinks forward declarations in a different file are redefinitions
  patch :p1, :DATA

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
    for_archs './test' do |a|
      arch_cmd = (a.nil? ? '' : "arch -arch #{a.to_s} ")
      assert_equal version.to_s, shell_output("#{arch_cmd}./test")
    end
  end # test
end # Libnghttp2

__END__
--- old/lib/nghttp2_submit.h	2024-06-08 16:12:54.000000000 -0700
+++ new/lib/nghttp2_submit.h	2024-06-08 16:13:47.000000000 -0700
@@ -30,8 +30,7 @@
 #endif /* HAVE_CONFIG_H */
 
 #include <nghttp2/nghttp2.h>
-
-typedef struct nghttp2_data_provider_wrap nghttp2_data_provider_wrap;
+#include "nghttp2_outbound_item.h"
 
 int nghttp2_submit_data_shared(nghttp2_session *session, uint8_t flags,
                                int32_t stream_id,
