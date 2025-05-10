module Merge
  include FileUtils

  module_function

  def stashdir; buildpath/'arch-stashes'; end

  # The keg_prefix and stash_root are expected to be Pathname objects.
  # The list members are just strings.
  def prep(keg_prefix, stash_root, list)
    list.each do |item|
      source = keg_prefix/item
      dest = stash_root/item
      mkdir_p dest.parent
      cp source, dest
    end # each binary
  end # Merge⸬prep

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
  end # Merge⸬scour_keg

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
          MacOS.lipo('-create', *arch_files, '-output', keg_prefix/spb)
        else
          # presumably there's a reason this only exists for one architecture, so no error;
          # the same rationale would apply if it only existed in, say, two out of three
          cp arch_files.first, keg_prefix/spb
        end # if > 1 file?
      end # if directory?
    end # each basename |b|
  end # Merge⸬binaries

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
        # TODO:  Ideally, overlapping and/or different-displacement hunks would be allowed for at
        # this point; but since most packages do not seem to generate such in the first place, it
        # can wait.  That said, packages exist (e.g. the originals of both Python 2 and Python 3)
        # which can and do generate quad fat binaries (and we want to some day support generating
        # them by default), so it can’t be ignored forever.
        basis_lines = []
        File.open(basis_file, 'r') { |text| basis_lines = text.read.lines[0..-1] }
        # Don’t forget, the line-array indices are one less than the line numbers.
        # Start with the last diff point so the insertions don’t screw up our line numbering:
        diffpoints.keys.sort.reverse.each do |index_string|
          diff_start = index_string.to_i - 1
          diff_end = diff_start + diffpoints[index_string][0][:displacement] - 1
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
  end # Merge⸬c_headers

  def pkg_cfg(pc_dir)
    pc_dir.children.select { |f|
      (not f.symlink?) and f.file? and f.fnmatch('*.pc')
    }.each do |f|
      fdata = f.read.gsub(/-arch \S+|-m32|-m64/, '')
      f.open('w') { |io| io.write(fdata) }
    end # each dir child |f|
  end # Merge⸬pkg_cfg
end # Merge
