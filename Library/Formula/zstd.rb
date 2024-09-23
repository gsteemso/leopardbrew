# Zstandard 1.5.6 requires C++14.  1.5.5 is the last version that can be built with Tiger‐/Leopard‐
#   era compilers.
class Zstd < Formula
  desc 'Zstandard - fast real-time compression algorithm (see RFC 8878)'
  homepage 'https://github.com/facebook/zstd/'
  url 'https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz'
  sha256 '9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4'

  option :universal
  option 'with-manpages', 'build man pages for zstd(1), zstdgrep(1), and zstdless(1)'

  if MacOS.version < :leopard
#    depends_on 'apple-gcc42' => :build  # may not actually be true, after patching
    depends_on 'cctools'     => :build  # Needs a more recent "as".
    depends_on 'ld64'        => :build  # Tiger's system `ld` can't build the library.
    depends_on 'make'        => :build  # Tiger's system `make` can't handle the makefile.
  end

  # the manpages depend on a Ruby gem called ronn (for turning Markdown into manpages)

  def install
    ENV.deparallelize
    # For some reason, type `long long` is not understood unless this is made explicit:
    ENV.append_to_cflags '-std=c99'
    if build.universal?
      ENV.permit_arch_flags if superenv?
      ENV.un_m64 if Hardware::CPU.family == :g5_64
      archs = Hardware::CPU.universal_archs
      dirs = []
    else
      archs = [MacOS.preferred_arch]
    end

    archs.each do |arch|
      if build.universal?
        ENV.append_to_cflags "-arch #{arch}"
        dir = "stash-#{arch}"
        mkdir dir
        dirs << dir
      end

      # The “install” target covers the static and the dynamic libraries and the CLI binaries.
      # The “manual” target covers the API documentation in HTML.
      args = %W[
        prefix=#{prefix}
        install
      ]
      args << 'V=1' if ARGV.verbose?
      args << 'man' if build.with? 'manpages'

      # `make check` et sim. are not used because they are specific to the zstd developers.
      make *args

      if build.universal?
        make 'clean'
        Merge.scour_keg(prefix, dir)
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
      end # universal?
    end # archs.each

    if build.universal?
      Merge.mach_o(prefix, dirs)
    end # universal?
  end # install

  test do
    system bin/'zstd', '-z', '-o', './zstdliest.zst', bin/'zstd'
    system bin/'zstd', '-t', 'zstdliest.zst'
    system bin/'zstd', '-d', 'zstdliest.zst'
    system 'diff', '-s', 'zstdliest', bin/'zstd'
  end
end

class Merge
  module Pathname_extension
    def is_bare_mach_o?
      # header word 0, magic signature:
      #   MH_MAGIC    = 'feedface' – value with lowest‐order bit clear
      #   MH_MAGIC_64 = 'feedfacf' – same value with lowest‐order bit set
      # low‐order 24 bits of header word 1, CPU type:  7 is x86, 12 is ARM, 18 is PPC
      # header word 3, file type:  no types higher than 10 are defined
      # header word 5, net size of load commands, is far smaller than the filesize
      if (self.file? and self.size >= 28 and mach_header = self.binread(24).unpack('N6'))
        raise('Fat binary found where bare Mach-O file expected') if mach_header[0] == 0xcafebabe
        ((mach_header[0] & 0xfffffffe) == 0xfeedface and
          [7, 12, 18].detect { |item| (mach_header[1] & 0x00ffffff) == item } and
          mach_header[3] < 11 and
          mach_header[5] < self.size)
      else
        false
      end
    end unless method_defined?(:is_bare_mach_o?)
  end # Pathname_extension

  class << self
    include FileUtils

    def scour_keg(keg_prefix, stash, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{keg_prefix}/#{s_p}*"].each do |f|
        pn = Pathname(f).extend(Pathname_extension)
        spb = s_p + pn.basename
        if pn.directory?
          Dir.mkdir "#{stash}/#{spb}"
          scour_keg(keg_prefix, stash, spb)
        # the number of things that look like Mach-O files but aren’t is horrifying, so test
        elsif ((not pn.symlink?) and pn.is_bare_mach_o?)
          cp pn, "#{stash}/#{spb}"
        end
      end
    end # scour_keg

    def mach_o(install_prefix, arch_dirs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dir_list = arch_dirs.join(',')
      Dir["{#{arch_dir_list}}/#{s_p}*"].map { |f|
        File.basename(f)
      }.each do |b|
        basename_list << b unless basename_list.count(b) > 0
      end
      basename_list.each do |b|
        spb = s_p + b
        the_arch_dir = arch_dirs.detect { |ad| File.exist?("#{ad}/#{spb}") }
        pn = Pathname("#{the_arch_dir}/#{spb}")
        if pn.directory?
          mach_o(install_prefix, arch_dirs, spb)
        else
          arch_files = Dir["{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', install_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, install_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # basename_list.each
    end # mach_o
  end # << self
end # Merge
