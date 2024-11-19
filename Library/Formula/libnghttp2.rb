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
  end

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
    if build.universal?
      ENV.permit_arch_flags if superenv?
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}" if build.universal?

      system 'autoreconf', '-ivf' if build.head?
      system './configure', "--prefix=#{prefix}",
                            '--disable-dependency-tracking',
                            '--disable-silent-rules',
                            '--enable-lib-only'
      cd 'lib' do
        system 'make'
        # `make check` does nothing
        system 'make', 'install'
        if build.universal?
          system 'make', 'distclean'
          Merge.scour_keg(prefix, stashdir/"bin-#{arch}")
          # undo architecture-specific tweak before next run
          ENV.remove_from_cflags "-arch #{arch}"
        end # universal?
      end # cd 'lib'
    end # archs.each

    Merge.binaries(prefix, stashdir, archs) if build.universal?
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
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', "#{a.to_s} "])
      assert_equal version.to_s, shell_output("#{arch_cmd * ' '}./test")
    end
  end # test
end # Libnghttp2

class Merge
  class << self
    include FileUtils

    # The stash_root is expected to be a Pathname object.
    # The keg_prefix and the sub_path are just strings.
    def scour_keg(keg_prefix, stash_root, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      stash_p = stash_root/s_p
      mkdir_p stash_p unless stash_p.directory?
      Dir["#{keg_prefix}/#{s_p}*"].each do |f|
        pn = Pathname.new(f)
        spb = s_p + pn.basename
        if pn.directory?
          scour_keg(keg_prefix, stash_root, spb)
        # the number of things that look like Mach-O files but aren’t is horrifying, so test
        elsif not(pn.symlink?) and (pn.mach_o_signature_at?(0) or pn.ar_sigseek_from 0)
          cp pn, stash_root/spb
        end # what is pn?
      end # each pathname
    end # Merge.scour_keg

    # The keg_prefix is expected to be a Pathname object.  The rest are just strings.
    def binaries(keg_prefix, stash_root, archs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dirs = archs.map {|a| "bin-#{a}"}
      arch_dir_list = arch_dirs.join(',')
      Dir["#{stash_root}/{#{arch_dir_list}}/#{s_p}*"].map { |f|
        File.basename(f)
      }.each { |b|
        basename_list << b unless basename_list.count(b) > 0
      }
      basename_list.each do |b|
        spb = s_p + b
        the_arch_dir = arch_dirs.detect { |ad| File.exist?("#{stash_root}/#{ad}/#{spb}") }
        pn = Pathname("#{stash_root}/#{the_arch_dir}/#{spb}")
        if pn.directory?
          binaries(keg_prefix, stash_root, archs, spb)
        else
          arch_files = Dir["#{stash_root}/{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', keg_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, keg_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # each basename |b|
    end # Merge.binaries
  end # << self
end # Merge

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
