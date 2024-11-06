# Zstandard 1.5.6 requires C++14.  1.5.5 is the last version that can be built with Tiger‐/Leopard‐
#   era compilers.
class Zstd < Formula
  desc 'Zstandard - fast real-time compression algorithm (see RFC 8878)'
  homepage 'https://github.com/facebook/zstd/'
  url 'https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5.tar.gz'
  sha256 '9c4396cc829cfae319a6e2615202e82aad41372073482fce286fac78646d3ee4'

  option :universal

  if MacOS.version < :leopard
    depends_on 'apple-gcc42' => :build  # may not actually be true
    depends_on 'cctools'     => :build  # Needs a more recent "as".
    depends_on 'ld64'        => :build  # Tiger's system `ld` can't build the library.
    depends_on 'make'        => :build  # Tiger's system `make` can't handle the makefile.
  end

  def install
    ENV.deparallelize
    # For some reason, type `long long` is not understood unless this is made explicit:
    ENV.append_to_cflags '-std=c99'
    if build.universal?
      ENV.permit_arch_flags
      ENV.delete('HOMEBREW_ARCHFLAGS')
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
      the_binaries = %w[
        bin/zstd
        lib/libzstd.1.5.5.dylib
        lib/libzstd.a
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    # The “install” Make target covers static & dynamic libraries, CLI binaries, and manpages.
    # The “manual” Make target (not used here) would cover API documentation in HTML.
    args = %W[
      prefix=#{prefix}
      install
    ]
    args << 'V=1' if VERBOSE

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}" if build.universal?

      # `make check` et sim. are not used because they are specific to the zstd developers.
      make *args

      if build.universal?
        make 'clean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
      end # universal?
    end # each |arch|

    Merge.binaries(prefix, stashdir, archs) if build.universal?
  end # install

  test do
    for_archs bin/'zstd' do |a|
      arch_args = (a ? ['arch', '-arch', a.to_s] : [])
      system *arch_args, bin/'zstd', '-z', '-o', './test.zst', test_fixtures('test.pdf')
      system *arch_args, bin/'zstd', '-t', 'test.zst'
      system *arch_args, bin/'zstd', '-d', '--rm', 'test.zst'
      system 'diff', '-s', 'test', test_fixtures('test.pdf')
      rm 'test'
    end # each arch |a|
  end # test
end # Zstd

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
