class Libarchive < Formula
  desc "Multi-format archive and compression library"
  homepage "http://www.libarchive.org"
  url "https://www.libarchive.org/downloads/libarchive-3.7.4.tar.xz"
  sha256 "f887755c434a736a609cbd28d87ddbfbe9d6a3bb5b703c22c02f6af80a802735"

  bottle do
    cellar :any
    sha256 "9c382bde083c41d3abab1be03642cf95a73151cc83514d57840a8fa9ae278f0c" => :tiger_altivec
  end

  option :universal

  depends_on "bzip2"
  depends_on "lz4"
  depends_on "xz"
  depends_on "zlib"

  keg_only :provided_by_osx

  def install
    if build.universal?
      ENV.permit_arch_flags if superenv?
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
      the_binaries = %w[
        bin/bsdcat
        bin/bsdcpio
        bin/bsdtar
        bin/bsdunzip
        lib/libarchive.13.dylib
        lib/libarchive.a
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}" if build.universal?

    system "./configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--disable-acl",
                          "--without-lzo2",
                          "--without-nettle",
                          "--without-xml2",
                          "--without-expat",
                          "ac_cv_header_sys_queue_h=no" # Use its up‐to‐date copy to obtain STAILQ_FOREACH
      system 'make'
      system 'make', 'check'  # verify this
      system "make", "install"

      if build.universal?
        system 'make', 'distclean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
      end # universal?
    end # each |arch|

    Merge.binaries(prefix, stashdir, archs) if build.universal?
  end # install

  test do
    (testpath/'test').write('test')
    for_archs bin/'bsdtar' do |a|
      arch_cmd = (a.nil? ? [] : ['arch', '-arch', a.to_s])
      system *arch_cmd, "#{bin}/bsdtar", '-czvf', 'test.tar.gz', 'test'
      assert_match /test/, shell_output("#{bin}/bsdtar -xOzf test.tar.gz")
      rm 'test.tar.gz'
    end
  end # test
end # Libarchive

class Merge
  class << self
    include FileUtils

    # The destination is expected to be a Pathname object.
    # The source is just a string.
    def cp_mkp(source, destination)
      if destination.exists?
        if destination.is_directory?
          cp source, destination
        else
          raise "File exists at destination:  #{destination}"
        end # directory?
      else
        mkdir_p destination.parent unless destination.parent.exists?
        cp source, destination
      end # destination exists?
    end # Merge.cp_mkp

    # The keg_prefix and stash_root are expected to be Pathname objects.
    # The list members are just strings.
    def prep(keg_prefix, stash_root, list)
      list.each do |item|
        source = keg_prefix/item
        dest = stash_root/item
        cp_mkp source, dest
      end # each binary
    end # Merge.prep

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
