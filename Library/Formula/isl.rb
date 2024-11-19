class Isl < Formula
  desc "Integer Set Library for the polyhedral model"
  homepage "https://libisl.sourceforge.io"
  # Note: Always use tarball instead of git tag for stable version.
  #
  # Currently isl detects its version using source code directory name
  # and update isl_version() function accordingly.  All other names will
  # result in isl_version() function returning "UNKNOWN" and hence break
  # package detection.
  url "https://libisl.sourceforge.io/isl-0.18.tar.bz2"
  mirror "https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2"
  sha256 "6b8b0fd7f81d0a957beb3679c81bbb34ccc7568d5682844d8924424a0dadcb1b"

  bottle do
    cellar :any
    sha256 "8561e09544a30e9d7bfef5483e9c54dff72c4ecd06ed2e7d3e4f9a3ef08f5dd0" => :tiger_g4e
    sha256 "478c188866c0ae28e7446f0a63fc13d5a3938766accc7a2c1bfaa040a2d378ad" => :leopard_g4e
  end

  option :universal

  head do
    url "https://repo.or.cz/r/isl.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "gmp"

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

      system "./autogen.sh" if build.head?
      system "./configure", "--disable-dependency-tracking",
                            "--disable-silent-rules",
                            "--prefix=#{prefix}",
                            "--with-gmp=system",
                            "--with-gmp-prefix=#{Formula["gmp"].opt_prefix}"
      system "make"
      system "make", "check"
      system "make", "install"

      if build.universal?
        system 'make', 'distclean'
        Merge.scour_keg(prefix, stashdir/"bin-#{arch}")
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
      end # universal?
    end # each |arch|

    Merge.binaries(prefix, stashdir, archs) if build.universal?

    (share/"gdb/auto-load").install Dir["#{lib}/*-gdb.py"]
  end # install

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <isl/ctx.h>

      int main()
      {
        isl_ctx* ctx = isl_ctx_alloc();
        isl_ctx_free(ctx);
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, "test.c", "-L#{lib}", "-lisl", "-o", "test"
    arch_system "./test"
  end # test
end # Isl

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
