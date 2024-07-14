class CAres < Formula
  desc "Asynchronous DNS library"
  homepage "http://c-ares.haxx.se/"
  homepage "https://c-ares.org/"
  url "https://github.com/c-ares/c-ares/releases/download/v1.31.0/c-ares-1.31.0.tar.gz"
  sha256 "0167a33dba96ca8de29f3f598b1e6cabe531799269fd63d0153aa0e6f5efeabd"

  head do
    url "https://github.com/c-ares/c-ares.git", :branch => 'main'
    depends_on 'autoconf' => :build
    depends_on 'automake' => :build
    depends_on 'libtool'  => :build
    depends_on 'm4'       => :build
  end

  option :universal

  def install
    system 'autoreconf', '-fi' if build.head?

    if build.universal?
      ENV.permit_arch_flags if superenv?
      ENV.un_m64 if Hardware::CPU.family == :g5_64
      archs = Hardware::CPU.universal_archs
      stashdir = 'arch-stashes'
      the_binaries = %w[
        lib/libcares.2.dylib
        lib/libcares.a
      ]
    else
      archs = [MacOS.preferred_arch]
    end

    archs.each do |arch|
      if build.universal?
        case arch
          when :i386, :ppc then ENV.m32
          when :ppc64, :x86_64 then ENV.m64
        end
      end

      system "./configure", "--prefix=#{prefix}",
                            "--disable-dependency-tracking",
                            '--enable-symbol-hiding'
      system "make"
      # running the unit tests requires both C++11 and `googletest`, which seems a lot more trouble
      # than it’s probably worth
      ENV.deparallelize { system "make", "install" }

      if build.universal?
        system 'make', 'clean'
        Merge.prep(prefix, buildpath/"#{stashdir}/bin-#{arch}", the_binaries)
        # undo architecture-specific tweaks before next run
        case arch
          when :i386, :ppc then ENV.un_m32
          when :ppc64, :x86_64 then ENV.un_m64
        end # case arch
      end # universal?
    end # archs.each

    Merge.mach_o(prefix, stashdir, archs) if build.universal?
  end # install

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <stdio.h>
      #include <ares.h>

      int main()
      {
        ares_library_init(ARES_LIB_INIT_ALL);
        ares_library_cleanup();
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, "test.c", "-L#{lib}", "-lcares", "-o", "test"
    system "./test"
  end # test
end # CAres

class Merge
  class << self
    include FileUtils

    # The keg_prefix and stash_root are expected to be Pathname objects.
    # The list members are just strings.
    def prep(keg_prefix, stash_root, list)
      list.each do |item|
        source = keg_prefix/item
        dest = stash_root/item
        mkpath dest.parent
        cp source, dest
      end # each binary
    end # prep

    # The keg_prefix is expected to be a Pathname object.  The rest are just strings.
    def mach_o(keg_prefix, stash_root, archs, sub_path = '')
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
          mach_o(keg_prefix, stash_root, archs, spb)
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
    end # mach_o
  end # << self
end # Merge
