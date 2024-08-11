class Mpg123 < Formula
  desc 'MP3 player for Linux and UNIX'
  homepage 'http://www.mpg123.de/'
  url 'https://downloads.sourceforge.net/projects/mpg123/files/mpg123/1.32.7/mpg123-1.32.7.tar.bz2'
  mirror 'http://www.mpg123.de/download/mpg123-1.32.7.tar.bz2'
  sha256 '3c8919243707951cac0e3c39bbf28653bcaffc43c98ff16801a27350db8f0f21'

  option :universal

  def install
    if build.universal?
      ENV.permit_arch_flags if superenv?
      ENV.un_m64 if Hardware::CPU.family == :g5_64
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
      the_binaries = %w[
        bin/mpg123
        bin/mpg123-id3dump
        bin/mpg123-strip
        bin/out123
        lib/libmpg123.0.dylib
        lib/libmpg123.a
        lib/libout123.0.dylib
        lib/libout123.a
        lib/libsyn123.0.dylib
        lib/libsyn123.a
        lib/mpg123/output_coreaudio.so
        lib/mpg123/output_dummy.so
        lib/mpg123/output_openal.so
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    args = [
      "--prefix=#{prefix}",
      '--disable-debug',
      '--disable-dependency-tracking',
      '--disable-silent-rules',
      '--enable-ipv6',
      '--enable-network',
      '--enable-static',
      '--with-default-audio=coreaudio,openal',
    ]

    archs.each do |arch|
      if build.universal?
        case arch
          when :i386, :ppc then ENV.m32
          when :ppc64, :x86_64 then ENV.m64
        end
      end # universal?

      case arch
        when :i386 then arch_args = ['--with-cpu=x86']  # include it all, could be Hackintosh or VM
        when :ppc, :ppc64 then arch_args = (Hardware::CPU.altivec? ? ['--with-cpu=altivec'] : [])
        when :x86_64 then arch_args = ['--with-cpu=x86-64']
      end

      system './configure', *args, *arch_args
      system 'make'
      system 'make', 'install'

      if build.universal?
        system 'make', 'clean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        # undo architecture-specific tweaks before next run
        case arch
          when :i386, :ppc then ENV.un_m32
          when :ppc64, :x86_64 then ENV.un_m64
        end # case arch
      end # universal?
    end # each |arch|

    Merge.binaries(prefix, stashdir, archs) if build.universal?
  end # install

  test do
    system bin/'mpg123', test_fixtures('test.mp3')
  end
end # Mpg123

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
