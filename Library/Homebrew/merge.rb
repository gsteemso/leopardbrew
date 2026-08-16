# Use this by `include`ing it in your formula recipe.
module Merge
  include FileUtils

  def stashroot; buildpath/'arch-stashes'; end

  # type is either :binary or :header; arch is anything implicitly coërced to a {String} by interpolation.
  # @private
  def stashdir(type, arch)
    arch = arch.keys.first if arch.is_a? Hash  # Accommodate partitioned archsets.
    subdir_basename = case type
                        when :binary then "bin-#{arch}"
                        when :header then "h-#{arch}"
                        else raise "unknown merge type:  #{type.inspect}"
                      end
    stashroot/subdir_basename
  end # stashdir()

  # type is either :binary or :header; the list members are {String}s; arch is anything implicitly coërced to one by interpolation.
  # Note that this method is unaffected by the current working directory.
  def merge_prep(type, arch, list)
    arch = arch.keys.first if arch.is_a? Hash  # Accommodate partitioned archsets.
    list.each do |rel_path|
      dest = stashdir(type, arch)/rel_path
      mkdir_p dest.parent unless dest.parent.directory?
      cp_p prefix/rel_path, dest
    end # each listed |rel_path|
  end # merge_prep

  # sub_path is a {String}; arch is anything implicitly coërced to one by interpolation.
  def scour_keg(arch, sub_path = nil)
    arch = arch.keys.first if arch.is_a? Hash  # Accommodate partitioned archsets.
    stash_root = stashdir(:binary, arch)
    stash_path = (sub_path ? stash_root/sub_path : stash_root)
    mkdir_p stash_path unless stash_path.directory?
    s_p = sub_path ? sub_path + '/' : ''  # Don’t suffer a double slash when sub_path is null.
    Dir["#{prefix}/#{s_p}*"].map{ |fn| Pathname(fn) }.each do |pn|
      spb = s_p + pn.basename
      if pn.directory? then scour_keg(arch, spb)
      elsif (not pn.symlink?) and (pn.machO_sig_at?(0) or pn.ar_sigseek_from 0) then cp_p pn, stash_root/spb; end
    end # each filename |fn|
  end # scour_keg

  # sub_path is a {String}; the members of archs are coërcible to {String}s via #to_s.
  def merge_binaries(archs, sub_path = nil)
    archs = archs.map{ |arch| arch.is_a?(Hash) ? arch.keys.first : arch }  # Accommodate partitioned archsets.
    # Generate a full list of files, even when some are not present on all architectures; bear in mind that the current _directory_
    # may not even exist on all archs.
    basename_list = []
    stashlist = stashdir(:binary, '').to_s + '{' + archs.map(&:to_s).join(',') + '}'
    s_p = sub_path ? sub_path + '/' : ''  # Don’t suffer a double slash when sub_path is null.
    Dir["#{stashlist}/#{s_p}*"].map{|fn| File.basename(fn)}.each{|bn| basename_list << bn unless basename_list.count(bn) > 0}
    stash_array = archs.map{ |a| stashdir(:binary, a) }
    basename_list.each do |bn|
      spb = s_p + bn
      next unless the_arch_dir = stash_array.detect{ |ad| (ad/spb).exists? }
      if (the_arch_dir/spb).directory? then merge_binaries(archs, spb)
      elsif (slice_names = Dir["#{stashlist}/#{spb}"]).length > 1  # In principle, this yields a list of single-architecture slices.
        exploded_names = []                                        # In practice, some or all of them may already be fat binaries.
        slice_names.each do |slice_name|
          if (pn = Pathname slice_name).fat_container?
            pn.lipo_archs.each{ |l_arch|
              system MacOS.lipo, '-thin', l_arch.to_s, '-output', (temp_fn = "#{slice_name}_#{l_arch}"), slice_name
              exploded_names << temp_fn
            }
          else exploded_names << slice_name; end
        end # each |slice_name|
        system MacOS.lipo, '-create', *exploded_names, '-output', prefix/spb
      else cp_p slice_names.first, prefix/spb; end
    end # each basename |b|
  end # merge_binaries

  # sub_path is a {String}; the members of archs are implicitly coërcible to {String}s by interpolation.
  def merge_C_headers(arch_parts, sub_path = nil)
    return if arch_parts.length < 2  # We needn’t do anything unless at least two different architectures or partitions are present.
    # Accommodate partitioned archsets.  We differentiate between the architecture/partition name, as used when we stashed affected
    # headers, and the actual architectures represented by each such name, used when we fuse the stashed files through preprocessor
    # conditionals.
    a_p_names = []; archsets = {}
    arch_parts.each{ |a_p|
      if a_p.is_a?(Hash) then a_p_names << a_p.keys.first; archsets[a_p.keys.first] = a_p.values.first
      else                    a_p_names << a_p;            archsets[a_p]            = [a_p]           ; end
    }
    # One or more architecture-specific header files need to be surgically combined, and were stashed for the purpose.  Differences
    # are relatively minor and can be “#ifdef”d together.  With full control of the stashdir, we can simplify by assuming each file
    # exists for all architectures.
    s_p = (sub_path ? sub_path + '/' : '')  # Don’t suffer a double slash when sub_path is null.
    Dir["#{stashdir(:header, a_p_names[0])}/#{s_p}*"].each do |basis_file|
      spb = s_p + File.basename(basis_file)
      if File.directory?(basis_file) then merge_C_headers(arch_parts, spb)
      else
        diffpoints = {}  # Keyed by line number in the basis file.  Each value is itself a {Hash}, keyed on the architecture & with
                         # two‐element {Hash} values.  Each such value has the textual displacement (the number of basis‐file lines
                         # replaced) and an {Array} of the displacing chunk’s lines.
        identicals = []  # Identifies any architectures for which this file is identical to the basis file.
        a_p_names[1..-1].each do |a|
          # Take diffs, with zero context.  Context means uninvolved lines get included between diffs, which can be catastrophic if
          # the diffs in question are intertwined with preprocessor conditionals.  We do not use -N / --new-file; if our assumption
          # that the file is present on all architectures is false, it’s best to expose that fact loudly.
          raw_diffs = Utils.popen_read('diff', '--minimal', '--unified=0', basis_file, (stashdir(:header, a)/spb).to_s)
          raise "Leopardbrew Merge module:  Problem `diff`ing C‐family header file:  #{spb} (exit status #{$?.exitstatus})" \
                                                                                                               if $?.exitstatus > 1
          if raw_diffs.chomp.empty? then identicals << a; next; end  # Don’t need to do anything else if the diff was empty.
          # The unified diff output begins with two lines identifying the source files, followed by a series of chunk records, each
          # describing one difference that was found.  Each chunk record begins with a line like this one:
          #     @@ -old_line_number,old_length_in_lines +new_line_number,new_length_in_lines @@
          # Since we record everything relative to the basis file, we ignore new_line_number.  If *_length_in_lines is 1, the “,1”
          # is omitted, and vexingly, if it is zero, *_line_number will be too low by one (at least with Apple’s `diff`).
          diff_chunks = raw_diffs.lines[2..-1].join('').split(%r{(?=^@@)})
          diff_chunks.each do |d|
            base_linenumber = d.match(%r{\A@@ -(\d+)})[1].to_i
            displacement = (temp = d.match(%r{\A@@ -\d+(,\d+)?})[1]) ? temp.lchop.to_i : 1
            base_linenumber += 1 if displacement == 0
            diffpoints[base_linenumber] = {} unless diffpoints.has_key?(base_linenumber)
            # We want the lines that are either unchanged between files, or only found in the non‐basis file – i.e., the ones which
            # have a leading ‘+’ or ‘ ’.  Shave that off as we read it.
            line_group = []; d.lines{ |line| line_group << line.lchop if line =~ %r{^[+ ]} }
            diffpoints[base_linenumber][a] = {:displacement => displacement, :lines => line_group}
          end # each diff chunk |d|
        end # each a_p |a|
        identicals.unshift a_p_names[0]
        a_p_ = a_p_names - identicals
        dfpt_keys = diffpoints.keys.sort
        # Identify how much of the basis file each diffpoint covers.
        max_disp = {}; diffpoints.each_pair{ |i, dfpt| max_disp[i] = dfpt.keys.map{ |a_p| dfpt[a_p][:displacement] }.max }
        basis_lines = ['']; File.open(basis_file, 'r') { |text| basis_lines += text.read.lines }  # Pad so indices == line nºs.
        if a_p_.length > 1  # We have more than one set of diffs to reconcile with the basis file.
          # Handle overlapping and/or different-displacement chunks by harmonizing chunk lengths.  As every line not in a diff will,
          # by definition, match the basis file, we can fix short records by copying it.  However, a long diff in one architecture/
          # partition could displace a basis‐file range coïncident with two or more shorter diffs in another arch or partition.  To
          # blindly pad every shorter diff to full length would produce conflicting chunks for the shorter diffs’ arch or partition
          # – coalescence must precede harmonization.  This could conflict with preprocessor conditionals, but that is unavoidable;
          # any which intersect the span affected are likely already damaged by the differing basis‐file displacements.
          # First, identify any overlaps.
          overlaps = {}; prior_overlap = nil
          dfpt_keys.each do |i|
            (overlaps[prior_overlap][:indices].include?(i) ? next : (prior_overlap = nil)) if prior_overlap
            overlap = []  # This is for the initial basis‐file line numbers of any overlapping chunks, and their net displacement.
            i_end = i + max_disp[i]; j = i + 1
            while j < i_end do
              if diffpoints.key?(j)  # We have an overlap.
                if (new_end = j + max_disp[j]) > i_end then i_end = new_end; end  # If the overlap is bigger, grow our test window.
                overlap << i if overlap.empty?; overlap << j
              end
              j += 1
            end # while not yet at the end of the chunk
            if not overlap.empty? then overlaps[i] = {:displacement => i_end - i, :indices => overlap}; prior_overlap = i; end
          end  # each diffpoint key |i|
          # Secondly, coalesce any chunks in each overlap that belong to the same architecture.
          overlaps.each_pair do |i, overlap|
            a_p_.each do |a_p|
              # Within this overlap, gather the chunks/fragments for each architecture.
              chunks = {}; coalesced = {}
              overlap[:indices].each do |j|
                next if diffpoints[j].nil?  # If we already deleted this while processing a previous architecture, skip it.
                dfpt = diffpoints[j].fetch(a_p, nil)
                chunks[j] = dfpt if dfpt
              end
              ch_keys = chunks.keys.sort
              unless ch_keys.empty?
                # Coalesce this arch’s chunk fragments.  If the first fragment starts late, fill in its missing preamble.
                coalesced = { :displacement => 0, :lines => [] }
                ch_keys.each do |j|
                  interstice_start = i + coalesced[:displacement]
                  interstice_length = j - interstice_start
                  coalesced[:lines] += (basis_lines[interstice_start, interstice_length] + chunks[j][:lines])
                  coalesced[:displacement] += interstice_length + chunks[j][:displacement]
                end # each chunk key |j|
                if (postamble_length = overlap[:displacement] - coalesced[:displacement]) > 0  # Short result; fill from basis file.
                  coalesced[:lines] += basis_lines[i + coalesced[:displacement], postamble_length]
                  coalesced[:displacement] += postamble_length
                end
              end # chunk‐fragment array not empty
              # Replace the fragmented chunks with the coalesced chunk.
              ch_keys.each{ |j| diffpoints[j].delete(a_p) }
              diffpoints[i][a_p] = coalesced
            end # each non‐basis architecture |a_p|
            # Clean out any newly‐emptied, formerly‐overlapping diffpoints.
            overlap[:indices].each{ |j| if diffpoints[j].keys.empty? then diffpoints.delete(j); max_disp.delete(j); end }
          end # each pair |i, overlap|
          dfpt_keys = diffpoints.keys.sort  # Regenerate this because of any entries we may have deleted.
        end # More than 2 diff sets to merge?
        # Insert conditional-compilation blocks gated on the architecture.  This doesn’t test for potential conflicts with existing
        # conditional-compilation blocks, because what to do if there _is_ one is far from obvious.  Walk the diffpoints in reverse
        # order so the insertions don’t screw up our line numbering.
        dfpt_keys.reverse_each do |i|
          # Include the basis‐file chunk in the diffpoint so it gets conditionalized properly.
          d = max_disp[i]; diffpoints[i][a_p_names[0]] = {:displacement => d, :lines => basis_lines[i, d]}
          chunk_archparts = diffpoints[i].keys.sort; metapartitions = [ [chunk_archparts.shift] ]
          # Minimize the number of conditional cases.  If two architectures have identical diff‐line sets, combine their handling.
          while not chunk_archparts.empty? do
            ch_a_p = chunk_archparts.shift
            lines_differ = true
            metapartitions.each{ |mp| if diffpoints[i][ch_a_p][:lines] == diffpoints[i][mp[0]][:lines]
                                        mp << ch_a_p; lines_differ = false; break
                                      end }
            metapartitions << [ch_a_p] if lines_differ
          end # while chunk_archparts is not empty
          # Drop any meta‐partition with null contents.  We don’t need a preprocessor conditional for that when we can simply leave
          # it out entirely.
          metapartitions.reject!{ |mp| diffpoints[i][mp.first][:lines].length == 0 }
          # A {metapartitions} entry is an {Array} of architecture and/or partition names.  These are not useable directly; we must
          # first convert each one to an archset (an {Array} strictly of architecture names).
          archset_groups = metapartitions.map{ |mp| mp.collect{ |a_p| archsets[a_p] }.flatten }
          combiner = '__) || defined(__'
          adjusted_lines = ["\#if defined(__#{archset_groups[0] * combiner}__)\n"]
          adjusted_lines.concat(diffpoints[i][metapartitions[0][0]][:lines])
          metapartitions.each_with_index{ |m_p, j|
            next if j == 0  # We already did the first batch.
            adjusted_lines << "\#elif defined(__#{archset_groups[j] * combiner}__)\n"
            adjusted_lines.concat(diffpoints[i][m_p[0]][:lines])
          }
          adjusted_lines << "\#endif\n"
          basis_lines = basis_lines[0..(i - 1)] + adjusted_lines + basis_lines[(i + max_disp[i])..-1]
        end # each diffpoint |i|
        File.new("#{prefix}/#{spb}", 'w').syswrite(basis_lines * '')
      end # if not a directory
    end # each |basis_file|
  end # merge_C_headers

  def merge_pkg_cfg(pc_dir)
    pc_dir.children.select{ |pn| pn.real_file? and pn.fnmatch('*.pc') }.each do |pn|
      fdata = pn.read.gsub(%r{-arch \S+|-m32|-m64}, '')
      pn.open('w') { |io| io.write(fdata) }
    end
  end # merge_pkg_cfg
end # Merge
