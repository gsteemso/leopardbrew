# Use this by `include`ing it in your formula recipe.
module Merge
  include FileUtils

  # type is either :binary or :header; arch is a simple string (or, by implicit coërcion, a symbol).
  # @private
  def stashdir(type, arch)
    subdir_basename = case type
                        when :binary then "bin-#{arch}"
                        when :header then "h-#{arch}"
                        else raise "unknown merge type:  #{type.inspect}"
                      end
    buildpath/"arch-stashes/#{subdir_basename}"
  end # stash_subdir_basename

  # type is either :binary or :header; arch and the list members are simple strings.
  def merge_prep(type, arch, list)
    list.each do |rel_path|
      dest = stashdir(type, arch)/rel_path
      mkdir_p dest.parent unless dest.parent.directory?
      cp prefix/rel_path, dest
    end # each listed |rel_path|
  end # merge_prep

  # The arch and sub_path are simple strings.
  def scour_keg(arch, sub_path = nil)
    stash_root = stashdir(:binary, arch)
    stash_path = (sub_path ? stash_root/sub_path : stash_root)
    mkdir_p stash_path unless stash_path.directory?
    s_p = sub_path ? sub_path + '/' : ''  # Don’t suffer a double slash when sub_path is null.
    Dir["#{prefix}/#{s_p}*"].each do |fn|
      pn = Pathname.new(fn)
      spb = s_p + pn.basename
      if pn.directory?
        scour_keg(arch, spb)
      elsif (not pn.symlink?) and (pn.mach_o_signature_at?(0) or pn.ar_sigseek_from 0)
        cp pn, stash_root/spb
      end # what is pn?
    end # each filename |fn|
  end # scour_keg

  # The archs members and sub_path are simple strings.
  def merge_binaries(archs, sub_path = nil)
    # Generate a full list of files, even if some are not present on all architectures; bear in
    # mind that the current _directory_ may not even exist on all archs.
    basename_list = []
    dir_archlist = stashdir(:binary, '').to_s + '{' + archs.map(&:to_s).join(',') + '}'
    s_p = sub_path ? sub_path + '/' : ''  # Don’t suffer a double slash when sub_path is null.
    Dir["#{dir_archlist}/#{s_p}*"].map{ |fn|
      File.basename(fn)
    }.each{ |bn|
      basename_list << bn unless basename_list.count(bn) > 0
    }
    arch_dirs = archs.map{ |a| stashdir(:binary, a) }
    basename_list.each do |bn|
      spb = s_p + bn
      the_arch_dir = arch_dirs.detect{ |ad| (ad/spb).exists? }
      if (the_arch_dir/spb).directory?
        merge_binaries(archs, spb)
      else
        arch_files = Dir["#{dir_archlist}/#{spb}"]
        if arch_files.length > 1
          system MacOS.lipo, '-create', *arch_files, '-output', prefix/spb
        else
          # Presumably there's a reason this only exists for one architecture, so no error; the
          # same rationale would apply if it only existed in, say, two out of three.
          cp arch_files.first, prefix/spb
        end # > 1 file?
      end # directory?
    end # each basename |b|
  end # merge_binaries

  # The archs members and sub_path are simple strings.
  def merge_c_headers(archs, sub_path = nil)
    # Architecture-specific <header>.<extension> files need to be surgically combined and were
    # stashed for this purpose.  The differences are relatively minor and can be “#if defined ()”
    # together.  We make the simplifying assumption that the architecture-dependent headers in
    # question are present on all architectures.
    s_p = (sub_path ? sub_path + '/' : '')  # Don’t suffer a double slash when sub_path is null.
    Dir["#{stashdir(:header, archs[0])}/#{s_p}*"].each do |basis_file|
      spb = s_p + File.basename(basis_file)
      if File.directory?(basis_file) then merge_c_headers(archs, spb)
      else
        diffpoints = {}  # Keyed by line number in the basis file.  Each value is an array of
                         # three‐element hashes, one per arch; each hash contains the arch, the
                         # hunk’s displacement (number of basis‐file lines it replaces), and an
                         # array of its lines.
        archs[1..-1].each do |a|
          raw_diffs = `diff --minimal --unified=0 #{basis_file} #{stashdir(:header, a)}/#{spb}`
          next unless raw_diffs
          # The unified diff output begins with two lines identifying the source files, which are
          # followed by a series of chunk records, each describing one difference that was found.
          # Each chunk record begins with a line that looks like:
          # @@ -line_number,length_in_lines +line_number,length_in_lines @@
          diff_chunks = raw_diffs.lines[2..-1].join('').split(%r{(?=^@@)})
          diff_chunks.each do |d|
            # lexical sorting of numbers requires that they all be the same length
            base_linenumber_string = ('00000' + d.match(%r{\A@@ -(\d+)})[1])[-6..-1]
            unless diffpoints.has_key?(base_linenumber_string)
              diffpoints[base_linenumber_string] = []
            end
            # if the chunk length is 1, the comma and second number are not present
            length_match = d.match(%r{\A@@ -\d+(?:,(\d+))?})[1].nope || 1
            line_group = []
            # We want the lines that are either unchanged between files, or only found in the non‐
            # basis file; and to shave off the leading ‘+’ or ‘ ’.
            d.lines{ |line| line_group << line.lchop if line =~ %r{^[+ ]} }
            diffpoints[base_linenumber_string] << {
                :arch => a,
                :displacement => length_match,
                :chunk_lines => line_group
              }
          end # each diff chunk |d|
        end # each arch |a|
        # TODO:  Ideally, overlapping and/or different-displacement chunks would be accommodated at
        # this point; but since most packages seem not to generate those in the first place, it can
        # wait.  However, packages do exist (e.g. the originals of both Python 2 and Python 3) that
        # can and will generate quad fat binaries (which we hope to some day allow generation of by
        # default), so it can’t be ignored forever.
        # This also does not check whether it might interfere with existing conditional-compilation
        # blocks, because what to do if it _would_ is far from obvious.
        basis_lines = []
        File.open(basis_file, 'r') { |text| basis_lines = text.read.lines }
        # Don’t forget, the line-array indices are one less than the line numbers.
        # Start with the last diff point so the insertions don’t screw up our line numbering:
        diffpoints.keys.sort.reverse.each do |index_string|
          diff_start = index_string.to_i - 1
          diff_length = diffpoints[index_string][0][:displacement]
          adjusted_lines = [
              "\#if defined (__#{archs[0]}__)\n",
              basis_lines[diff_start, diff_length],
              *(diffpoints[index_string].map{ |dp|
                  [ "\#elif defined (__#{dp[:arch]}__)\n", *(dp[:chunk_lines]) ]
                }),
              "\#endif\n"
            ]
          basis_lines[diff_start, diff_length] = adjusted_lines
        end # each diffpoint |index_string|
        File.new("#{prefix}/#{spb}", 'w').syswrite(basis_lines.join(''))
      end # if not a directory
    end # each |basis_file|
  end # merge_c_headers

  def merge_pkg_cfg(pc_dir)
    pc_dir.children.select{ |f|
      (not f.symlink?) and f.file? and f.fnmatch('*.pc')
    }.each do |f|
      fdata = f.read.gsub(%r{-arch \S+|-m32|-m64}, '')
      f.open('w') { |io| io.write(fdata) }
    end # each pkgconfig file |f|
  end # merge_pkg_cfg
end # Merge
