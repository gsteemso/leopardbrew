class Keg
  PREFIX_PLACEHOLDER = "@@HOMEBREW_PREFIX@@".freeze
  CELLAR_PLACEHOLDER = "@@HOMEBREW_CELLAR@@".freeze

  def fix_install_names
    mach_o_files.each do |file|
      file.ensure_writable do
        change_dylib_id(dylib_id_for(file), file) if file.dylib?
        each_install_name_for(file) do |bad_name|
          # Don't fix absolute paths unless rooted in one of:  - the build directory
          #                                                    - the Cellar
          #                                                    - a HOMEBREW_PREFIX symlink
          # Either of those latter two can fail catastrophically when things are temporarily
          # moved for a reïnstallation, as the third also will if its target is not linked.
          next if bad_name.starts_with?('/') and not(bad_name.starts_with?(HOMEBREW_TEMP.to_s) or
                                                     bad_name.starts_with?(HOMEBREW_CELLAR.to_s) or
                                                     bad_name.starts_with?(HOMEBREW_PREFIX.to_s))
          new_name = fixed_name(file, bad_name)
          change_install_name(bad_name, new_name, file) unless new_name == bad_name
        end # each install name |bad_name| in file
      end # file.ensure_writable
    end # each Mach-O |file|
    symlink_files.each do |file|
      link = file.readlink
      next unless link.absolute?  # Don't fix relative symlinks
      FileUtils.ln_sf(link.relative_path_from(file.parent), file) \
        if link.realpath.to_s.starts_with?(HOMEBREW_CELLAR.to_s) \
           or link.to_s.starts_with?(HOMEBREW_PREFIX.to_s)
    end # each symlink |file|
  end # fix_install_names

  def relocate_install_names(old_prefix, new_prefix, old_cellar, new_cellar)
    mach_o_files.each do |file|
      file.ensure_writable do
        if file.dylib?
          id = dylib_id_for(file).sub(old_prefix, new_prefix)
          change_dylib_id(id, file)
        end
        each_install_name_for(file) do |old_name|
          if old_name.starts_with? old_cellar then new_name = old_name.sub(old_cellar, new_cellar)
          elsif old_name.starts_with? old_prefix then new_name = old_name.sub(old_prefix, new_prefix)
          end
          change_install_name(old_name, new_name, file) if new_name and new_name != old_name
        end # each install name |old_name| in file
      end # file.ensure_writable block
    end # each Mach-O |file|
  end # relocate_install_names

  def relocate_text_files(old_prefix, new_prefix, old_cellar, new_cellar)
    files = text_files | libtool_files
    files.group_by { |f| f.stat.ino }.each_value do |first, *rest|
      s = first.open("rb", &:read)
      changed = s.gsub!(old_cellar, new_cellar)
      changed = s.gsub!(old_prefix, new_prefix) || changed
      begin
        first.atomic_write(s)
      rescue SystemCallError
        first.ensure_writable do first.open("wb") { |f| f.write(s) }; end
      else
        rest.each { |file| FileUtils.ln(first, file, :force => true) }
      end if changed
    end # each stat.ino group of files |first, *rest|
  end # relocate_text_files

  def change_dylib_id(id, file)
    puts "Changing dylib ID of #{file}\n  from #{file.dylib_id}\n    to #{id}" if DEBUG
    install_name_tool("-id", id, file)
  end

  def change_install_name(old, new, file)
    puts "Changing install name in #{file}\n  from #{old}\n    to #{new}" if DEBUG
    install_name_tool("-change", old, new, file)
  end

  # Detects the C++ dynamic libraries in place, scanning the dynamic links
  # of the files within the keg.
  # Note that this doesn't attempt to distinguish between libstdc++ versions,
  # for instance between Apple libstdc++ and GNU libstdc++
  def detect_cxx_stdlibs(options = {})
    skip_executables = options.fetch(:skip_executables, false)
    results = Set.new
    mach_o_files.each do |file|
      next if file.mach_o_executable? && skip_executables
      dylibs = file.dynamically_linked_libraries
      results << :libcxx unless dylibs.grep(/libc\+\+.+\.dylib/).empty?
      results << :libstdcxx unless dylibs.grep(/libstdc\+\+.+\.dylib/).empty?
    end

    results.to_a
  end # detect_cxx_stdlibs

  def each_unique_file_matching(string)
    Utils.popen_read("/usr/bin/fgrep", "-lr", string, to_s) do |io|
      hardlinks = Set.new
      until io.eof?
        file = Pathname.new(io.readline.chomp)
        next if file.symlink?
        yield file if hardlinks.add? file.stat.ino
      end
    end
  end # each_unique_file_matching

  def install_name_tool(*args)
    @require_install_name_tool = true
    tool = MacOS.install_name_tool
    system(tool, *args) or raise(ErrorDuringExecution.new(tool, args))
  end

  def require_install_name_tool?; !!@require_install_name_tool; end

  def fixed_name(file, bad_name)
    # Before we can do anything, must get rid of placeholders.
    if bad_name.starts_with? PREFIX_PLACEHOLDER
      working_name = bad_name.sub(PREFIX_PLACEHOLDER, HOMEBREW_PREFIX.to_s)
    elsif bad_name.starts_with? CELLAR_PLACEHOLDER
      working_name = bad_name.sub(CELLAR_PLACEHOLDER, HOMEBREW_CELLAR.to_s)
    else working_name = bad_name; end
    unless working_name.starts_with? '/'  # It’s relative and still equals bad_name.
      # If file is a dylib or bundle itself, look for the dylib named by
      # bad_name relative to the lib directory, so that we can skip the more
      # expensive recursive search if possible.
      if (file.dylib? or file.mach_o_bundle?) and (file.parent/bad_name).exists?
        return "@loader_path/#{bad_name}"
      elsif (lib/bad_name).exists? then return "#{opt_record}/lib/#{bad_name}"
      elsif (abs_name = find_dylib(Pathname.new(bad_name).basename)) and abs_name.exists?
        working_name = abs_name.to_s; end
    end # working_name is relative?
    # working_name is now definitely an absolute path.
    # If it’s in our own installed prefix, or anywhere else in the Cellar, it
    # will break if its referent has been moved for reïnstallation.
    if working_name.starts_with? HOMEBREW_CELLAR.to_s
      keg = Keg.for(working_name)
      return working_name.sub(keg.base.to_s, keg.opt_record.to_s)
    # If working_name is one of our symlinks in the PREFIX, it will break
    # when its target is unlinked.
    elsif working_name.starts_with? HOMEBREW_PREFIX.to_s
      return working_name if working_name.starts_with? OPTDIR.to_s
      bad_path = Pathname.new(working_name)
      return working_name unless bad_path.symlink? and
                    (real_bad = bad_path.resolved_real_path).to_s.starts_with? HOMEBREW_CELLAR.to_s
      return working_name.sub(HOMEBREW_PREFIX.to_s, (Keg.for(real_bad)).opt_record.to_s)
    end # is it in the Cellar or the PREFIX?
    opoo "Could not fix #{bad_name} in #{file}"
    bad_name
  end # fixed_name

  def lib; path/'lib'; end

  def each_install_name_for(file, &block)
    dylibs = file.dynamically_linked_libraries
    dylibs.reject! { |fn| fn =~ /^@(loader_|executable_|r)path/ }
    dylibs.each(&block)
  end

  def dylib_id_for(file)
    # The new dylib ID needs the same basename as the old dylib ID, not that of the file itself.
    dylib_basename = File.basename(file.dylib_id)
    # We want the same path WITHIN the keg.
    relative_dirname = file.dirname.relative_path_from(path)
    # A shortcut was once here using the HOMEBREW_CELLAR path instead of the HOMEBREW_PREFIX one.
    # However, that technique failed with software that had been unlinked, making it impossible to
    # upgrade anything used when brewing (like the support libraries for brewed GCC).  Worse, even
    # Cellar-based links fail during a reïnstallation.  Happily, links based on the opt prefix do
    # work here, though their nature as symlinks makes them a bit fragile.
    opt_record/relative_dirname/dylib_basename
  end # dylib_id_for

  def find_dylib(name); lib.find { |pn| break pn if pn.basename == name } if lib.directory?; end

  def mach_o_files
    mach_o_files = []
    path.find do |pn|
      next if pn.symlink? or pn.directory?
      mach_o_files << pn if pn.dylib? or pn.mach_o_bundle? or pn.mach_o_executable?
    end

    mach_o_files
  end # mach_o_files

  def text_files
    text_files = []
    path.find do |pn|
      next if pn.symlink? or pn.directory?
      next if Metafiles::EXTENSIONS.include? pn.extname
      text_files << pn \
        if Utils.popen_read("/usr/bin/file", "--brief", pn).include?("text") or pn.text_executable?
    end

    text_files
  end # text_files

  def libtool_files
    libtool_files = []
    # find .la files, which are stored in lib/
    lib.find do |pn|
      next if pn.symlink? or pn.directory? or pn.extname != ".la"
      libtool_files << pn
    end if lib.directory?

    libtool_files
  end # libtool_files

  def symlink_files
    symlink_files = []
    path.find { |pn| symlink_files << pn if pn.symlink? }

    symlink_files
  end # symlink_files
end # Keg
