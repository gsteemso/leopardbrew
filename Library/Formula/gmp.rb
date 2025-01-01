class Gmp < Formula
  desc "GNU multiple precision arithmetic library"
  homepage "https://gmplib.org/"
  url "https://gmplib.org/download/gmp/gmp-6.3.0.tar.lz"  # the .lz is smaller than the .xz
  mirror "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.lz"
  sha256 "be5c908a7a836c3a9bd9d62aa58563c5e9e7fef94c43a7f42dbc35bb6d02733c"

  bottle do
    sha256 "fe8558bf7580c9c8a3775016eccf61249b8d637b1b2970942dba22444c48da7d" => :tiger_altivec
  end

  option :universal

  def install
    # utility routine:  map Tigerbrew’s CPU symbols to those for configuring a GMP build
    def cpu_lookup(cpu_sym)
      case cpu_sym
        when :g3  then 'powerpc750'
        when :g4  then 'powerpc7400'
        when :g4e then 'powerpc7450'
        when :g5  then 'powerpc970'
        when :core      then 'pentiumm'
        when :penryn    then 'core2'
        when :arrandale then 'westmere'
        when :dunno     then 'unknown'
        else cpu_sym.to_s
      end
    end # cpu_lookup

    build_cpu = Hardware::CPU.model
    tuple_trailer = "apple-darwin#{`uname -r`.to_i}"

    if build.universal?
      archs = Hardware::CPU.universal_archs
      stashdir = buildpath/'arch-stashes'
      the_binaries = %w[
        lib/libgmp.10.dylib
        lib/libgmp.a
        lib/libgmpxx.4.dylib
        lib/libgmpxx.a
      ]
      the_headers = %w[
        gmp.h
      ]
    else
      archs = [MacOS.preferred_arch]
    end # universal?

    args = [
      "--prefix=#{prefix}",
      '--disable-silent-rules',
      '--enable-cxx'
    ]
    args << '--disable-assembly' if Hardware.is_32_bit?

    host_sym = (build.bottle? ? (ARGV.bottle_arch or Hardware.oldest_cpu) : build_cpu)
    if (looked_up_host = cpu_lookup(host_sym)) != (looked_up_build = cpu_lookup(build_cpu))
      args << "--build=#{looked_up_build}-#{tuple_trailer}"
      args << "--host=#{looked_up_host}-#{tuple_trailer}"
    end

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}"
      ENV.append_to_cflags '-force_cpusubtype_ALL' if looked_up_host == 'powerpc970'

      arch_args = case arch
        when :i386 then ['ABI=32']
        when :ppc
          case host_sym
            when :g3, :g4 then ['ABI=32']
            when :g5 then ['ABI=mode32']
          end
        when :ppc64 then ['ABI=mode64']
        when :x86_64 then ['ABI=64']
      end

      system './configure', *args, *arch_args
      system 'make'
      system 'make', 'check'
      ENV.deparallelize { system 'make', 'install' }

      if build.universal?
        system 'make', 'distclean'
        Merge.prep(prefix, stashdir/"bin-#{arch}", the_binaries)
        Merge.prep(include, stashdir/"h-#{arch}", the_headers)
        # undo architecture-specific tweaks before next run
        ENV.remove_from_cflags "-arch #{arch}"
        ENV.remove_from_cflags '-force_cpusubtype_ALL' if looked_up_host == 'powerpc970'
      end # universal?
    end # each |arch|

    if build.universal?
      Merge.binaries(prefix, stashdir, archs)
      Merge.c_headers(include, stashdir, archs)
    end # universal?
  end # install

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <gmp.h>
      #include <stdlib.h>

      int main() {
        mpz_t i, j, k;
        mpz_init_set_str (i, "1a", 16);
        mpz_init (j);
        mpz_init (k);
        mpz_sqrtrem (j, k, i);
        if (mpz_get_si (j) != 5 || mpz_get_si (k) != 1) abort();
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, "test.c", "-L#{lib}", "-lgmp", "-o", "test"
    system "./test"
  end # test
end #Gmp

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

    def c_headers(include_dir, stash_root, archs, sub_path = '')
      # Architecture-specific <header>.<extension> files need to be surgically combined and were
      # stashed for this purpose.  The differences are relatively minor and can be “#if defined ()”
      # together.  We make the simplifying assumption that the architecture-dependent headers in
      # question are present on all architectures.
      #
      # Don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{stash_root}/h-#{archs[0]}/#{s_p}*"].each do |basis_file|
        spb = s_p + File.basename(basis_file)
        if File.directory?(basis_file)
          c_headers(include_dir, stash_root, archs, spb)
        else
          diffpoints = {}  # Keyed by line number in the basis file.  Each value is an array of
                           # three‐element hashes; containing the arch, the hunk’s displacement
                           # (number of basis‐file lines it replaces), and an array of its lines.
          archs[1..-1].each do |a|
            raw_diffs = `diff --minimal --unified=0 #{basis_file} #{stash_root}/h-#{a}/#{spb}`
            next unless raw_diffs
            # The unified diff output begins with two lines identifying the source files, which are
            # followed by a series of hunk records, each describing one difference that was found.
            # Each hunk record begins with a line that looks like:
            # @@ -line_number,length_in_lines +line_number,length_in_lines @@
            diff_hunks = raw_diffs.lines[2..-1].join('').split(/(?=^@@)/)
            diff_hunks.each do |d|
              # lexical sorting of numbers requires that they all be the same length
              base_linenumber_string = ('00000' + d.match(/\A@@ -(\d+)/)[1])[-6..-1]
              unless diffpoints.has_key?(base_linenumber_string)
                diffpoints[base_linenumber_string] = []
              end
              length_match = d.match(/\A@@ -\d+,(\d+)/)
              # if the hunk length is 1, the comma and second number are not present
              length_match = (length_match == nil ? 1 : length_match[1].to_i)
              line_group = []
              # we want the lines that are either unchanged between files or only found in the non‐
              # basis file; and to shave off the leading ‘+’ or ‘ ’
              d.lines { |line| line_group << line[1..-1] if line =~ /^[+ ]/ }
              diffpoints[base_linenumber_string] << {
                :arch => a,
                :displacement => length_match,
                :hunk_lines => line_group
              }
            end # each diff hunk |d|
          end # each arch |a|
          # Ideally, the logic would account for overlapping and/or different-displacement hunks at
          # this point; but since most packages do not seem to generate such in the first place, it
          # can wait.  That said, packages exist (e.g. both Python 2 and Python 3) which can and do
          # generate quad fat binaries (and we want to some day support generating them by default),
          # so it can’t be ignored forever.
          basis_lines = []
          File.open(basis_file, 'r') { |text| basis_lines = text.read.lines[0..-1] }
          # Don’t forget, the line-array indices are one less than the line numbers.
          # Start with the last diff point so the insertions don’t screw up our line numbering:
          diffpoints.keys.sort.reverse.each do |index_string|
            diff_start = index_string.to_i - 1
            diff_end = index_string.to_i + diffpoints[index_string][0][:displacement] - 2
            adjusted_lines = [
              "\#if defined (__#{archs[0]}__)\n",
              basis_lines[diff_start..diff_end],
              *(diffpoints[index_string].map { |dp|
                  [ "\#elif defined (__#{dp[:arch]}__)\n", *(dp[:hunk_lines]) ]
                }),
              "\#endif\n"
            ]
            basis_lines[diff_start..diff_end] = adjusted_lines
          end # each key |index_string|
          File.new("#{include_dir}/#{spb}", 'w').syswrite(basis_lines.join(''))
        end # if not a directory
      end # each |basis_file|
    end # Merge.c_headers
  end # << self
end # Merge
