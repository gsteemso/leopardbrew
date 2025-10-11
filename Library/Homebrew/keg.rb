require 'extend/pathname'
require 'keg_relocate'
require 'formula/lock'
require 'ostruct'

class Keg
  class AlreadyLinkedError < RuntimeError
    def initialize(keg)
      super <<-EOS.undent
          Cannot link #{keg.name}
          Another version is already linked:  #{keg.linked_keg_record.resolved_path}
        EOS
    end # initialize
  end # AlreadyLinkedError

  class LinkError < RuntimeError
    attr_reader :keg, :tgt, :lnk
    def initialize(keg, tgt, lnk, cause)
      @tgt = tgt
      @lnk = lnk
      @keg = keg
      @cause = cause
      super(cause.message)
      set_backtrace(cause.backtrace)
    end # initialize
  end # LinkError

  class ConflictError < LinkError
    def suggestion
      conflict = Keg.for(lnk)
    rescue NotAKegError, Errno::ENOENT
      "already exists.  You may want to remove it:\n    rm '#{lnk}'\n"
    else <<-EOS.undent
        is a symlink belonging to #{conflict.name}.  You can unlink it:
            brew unlink #{conflict.name}

      EOS
    end # suggestion

    def to_s
      s = []
      s << "Could not symlink #{tgt}"
      s << "Object at #{lnk}" << suggestion
      s << <<-EOS.undent
          To force the link and overwrite all conflicting files:
              brew link --overwrite #{keg.name}

          To list all files that would be deleted:
              brew link --overwrite --dry-run #{keg.name}
        EOS
      s.join("\n")
    end # to_s
  end # ConflictError

  class DirectoryNotWritableError < LinkError
    def to_s; <<-EOS.undent
      Could not symlink #{tgt}
      #{lnk.dirname} is not writable.
      EOS
    end
  end # DirectoryNotWritableError

  INFOFILE_RX = %r{info/(dir|[^.].*\.info)$}
  # locale-specific directories have the form language[_territory][.codeset[@modifier]]
  LOCALEDIR_RX = %r{(locale|man)/([a-z]{2}|C|POSIX)(_[A-Z]{2})?(\.[a-zA-Z\-0-9]+(@.+)?)?}
  TOP_LEVEL_DIRECTORIES = %w[Frameworks bin etc include lib sbin share var]
  PRUNEABLE_DIRECTORIES = %w[Frameworks bin etc include lib sbin share].map { |d| HOMEBREW_PREFIX/d }
  PRUNEABLE_DIRECTORIES << LINKDIR

  # These paths relative to the keg's share directory (including man/*) should
  # always be real directories in the prefix, never symlinks.
  SHARE_PATHS = %w[
    aclocal doc info locale
    applications gnome gnome/help
    icons mime-info pixmaps sounds
  ]
  MAN_RX = %r{^man(/(cat|man)\d?[^/]{0,5})?$}
  MANPAGE_RX = %r{^man(/(cat|man)\d?[^/]{0,5})?}

  # During reïnstallations, the old keg must remain in service or reïnstalling anything used during
  # brewing becomes impossible.  We achieve this by temporarily renaming it (which is much easier &
  # less fragile than installing the replacement to a temporary location, then permanently renaming
  # that instead).
  REINSTALL_SUFFIX = '.being_reinstalled'

  # If path leads to a file in a keg, this will return the containing Keg object.
  def self.for(path, _cellar = HOMEBREW_CELLAR)
    pn = Pathname.new(path).realpath
    until pn.root?
      return Keg.new(pn) if pn.parent.parent == _cellar
      pn = pn.parent.realpath # realpath() prevents .root? failing
    end
    raise NotAKegError, path
  end # Keg::for

  attr_reader :path, :installed_prefix, :name, :linked_keg_record, :opt_record, :version_s
  private :installed_prefix, :version_s

  def initialize(path, _cellar = HOMEBREW_CELLAR)
    raise 'Can’t make a keg from a nil pathname' unless path
    pn = (Pathname === path ? path : Pathname.new(path))
    raise "#{path} is not a valid keg" unless pn.directory? and pn.realpath.parent.parent == _cellar.realpath
    @path = pn
    @version_s = pn.basename(REINSTALL_SUFFIX).to_s
    @name = rack.basename.to_s
    @installed_prefix = HOMEBREW_CELLAR/name/version_s
    @linked_keg_record = LINKDIR/name
    @opt_record = OPTDIR/name
  end # initialize

  def to_s; path.to_s; end
  alias_method :to_path, :to_s

  def rack; path.parent; end

  def versioned_name; "#{name}=#{version_s}"; end

  def formula
    if (f = Formulary.from_rack(rack)).installed? then f
    elsif (path/Tab::FILENAME).file? and (f = Formulary.from_keg(path)) then f
    end
  end

  def formula!; formula or raise FormulaVersionUnavailableError.new(name, version_s); end

  def spec
    (path/Tab::FILENAME).file? ? Tab.for_keg(path).spec \
                               : (version_s.starts_with? 'HEAD' ? :head : :stable)  # usually correct, :devel is rare
  end

  def inspect; "#<#{self.class.name}:#{path}>"; end

  def ==(other); instance_of?(other.class) && path == other.path; end
  alias_method :eql?, :==

  def hash; path.hash; end

  # Print a summary:  Number of files, & how much storage they occupy.
  def abv; path.abv; end

  def directory?; path.directory?; end

  def exists?; path.exists?; end
  alias :exist? :exists?

  def /(other); path/other; end

  def join(*args); path.join(*args); end

  private

  def reinstall_nameflip
    (path.extname == REINSTALL_SUFFIX) ? installed_prefix.to_s : "#{path.to_s}#{REINSTALL_SUFFIX}"
  end

  public

  def rename(new_name = reinstall_nameflip)
    unlink if was_linked = linked?
    path.rename new_name            # Rename the physical directory.
    @path = Pathname.new new_name   # Change our record of the name.
    optlink                         # Always regenerate the optlink.
    link if was_linked
  end # rename

  def linked?
    linked_keg_record.symlink? and linked_keg_record.directory? and path == linked_keg_record.resolved_path
  end

  def remove_linked_keg_record
    linked_keg_record.unlink
    linked_keg_record.parent.rmdir_if_possible
  end

  def optlinked?; opt_record.symlink? and path == opt_record.resolved_path; end

  def remove_opt_record; opt_record.unlink if opt_record.exists?; opt_record.parent.rmdir_if_possible; end

  def uninstall
    path.rmtree
    path.parent.rmdir_if_possible
    remove_opt_record if optlinked?
    remove_oldname_opt_record
  end # uninstall

  def unlink(mode = OpenStruct.new)
    ObserverPathnameExtension.reset_counts!
    dirs = []
    TOP_LEVEL_DIRECTORIES.map { |d| path/d }.each do |dir|
      next unless dir.exists?
      dir.find do |tgt|
        lnk = HOMEBREW_PREFIX/tgt.relative_path_from(path)
        lnk.extend(ObserverPathnameExtension)
        next unless lnk.exists?
        if lnk.symlink? and tgt == lnk.resolved_path  # only unlink a file from the current keg
          if mode.dry_run then puts lnk
          else
            lnk.uninstall_info if lnk.to_s =~ INFOFILE_RX
            lnk.unlink
          end
        end
        if tgt.directory? then if tgt.symlink? then Find.prune; else dirs << lnk; end; end
      end # find |tgt|
    end # each top‐level directory |dir|
    remove_linked_keg_record if linked? and not mode.dry_run
    dirs.reverse_each do |d|
      if mode.dry_run then puts "Would attempt to remove #{d}"; else d.rmdir_if_possible; end
    end

    ObserverPathnameExtension.total
  end # unlink

  def lock
    FormulaLock.new(name).with_lock{
      if oldname_opt_record then FormulaLock.new(oldname_opt_record.basename.to_s).with_lock{ yield }
      else yield; end }
  end

  def completion_installed?(shell)
    dir = case shell
            when :bash then path/'etc/bash_completion.d'
            when :fish then path/'share/fish/vendor_completions.d'
            when :zsh  then path/'share/zsh/site-functions'
          end
    dir and dir.directory? and dir.children.any?
  end # completion_installed?

  def plist_installed?; Dir["#{path}/*.plist"].any?; end

  def python2_site_packages_installed?; (path/'lib/python2.7/site-packages').directory?; end

  def python2_pth_files_installed?; Dir["#{path}/lib/python2.7/site-packages/*.pth"].any?; end

  private

  def py3xy; Formula['python3'].xy; end

  public

  def python3_site_packages_installed?
    (candidate = Dir["#{path}/lib/python#{py3xy}/site-packages"].first) && File.directory?(candidate)
  end

  def python3_pth_files_installed?; Dir["#{path}/lib/python#{py3xy}/site-packages/*.pth"].any?; end

  def app_installed?; Dir["#{path}/{,libexec/}*.app"].any?; end

  def elisp_installed?; Dir["#{path}/share/emacs/site-lisp/**/*.el"].any?; end

  def version
    require 'pkg_version'
    PkgVersion.parse(installed_prefix.basename.to_s)
  end

  def find(*args, &block); path.find(*args, &block); end

  def oldname_opt_record
    @oldname_opt_record ||= \
      OPTDIR.subdirs.detect do |dir|
        dir.symlink? and dir != opt_record and dir.resolved_path.parent == rack
      end if OPTDIR.directory?
  end # oldname_opt_record

  def link(mode = OpenStruct.new)
    raise AlreadyLinkedError.new(self) if linked_keg_record.directory?

    ObserverPathnameExtension.reset_counts!

    # you have to force anything you need in the main tree into these dirs
    # REMEMBER that *NOT* everything needs to be in the main tree

    link_dir('Frameworks', mode) do |relative_path|
        # Frameworks contain symlinks pointing into a subdir, so we have to use :link.  However, for
        # Foo.framework and Foo.framework/Versions we have to use :mkpath so that multiple formula
        # versions can link into it and still have `brew [un]link` work.
        (relative_path.to_s =~ %r{[^/]*\.framework(/Versions)?$}) \
                                            ? :mkdir \
                                            : :link
      end # link_dir Frameworks
    link_dir('bin',        mode) {            :skip_dirs }
    link_dir('etc',        mode) {            :link_tree }
    link_dir('include',    mode) {            :link      }
    link_dir('lib',        mode) do |relative_path|
        case relative_path.to_s
          when 'charset.alias'           then :skip_this
          # cmake & pkg-config databases, plus lib/<language> folders, get explicitly created
          when 'cmake', 'dtrace', 'ghc', 'lua', 'php', 'pkgconfig',
               %r{^(R|gdk-pixbuf|gio|mecab|node|ocaml|perl5|python[23]\.\d+|ruby)[^/]*$}
                                         then :mkdir
                                         else :link   # Everything else is symlinked to the cellar
        end
      end # link_dir lib
    link_dir('sbin',       mode) {            :skip_dirs }
    link_dir('share',      mode) do |relative_path|
        case relative_path.to_s
          when %r{^icons/.*/icon-theme\.cache$},
               'locale/locale.alias'     then :skip_this
          when INFOFILE_RX               then :info
          when 'fish',
               'fish/vendor_completions.d',
               'gtk-doc', 'gtk-doc/html',
               'icons', 'ri', *SHARE_PATHS,
               'zsh', 'zsh/site-functions',
               MAN_RX                    then :mkdir
          when %r{^(fish/vendor_completions.d|icons|zsh/site-functions)/}, LOCALEDIR_RX
                                         then :link_tree
                                         else :link
        end
      end # link_dir share

    make_relative_symlink(linked_keg_record, path, mode) unless mode.dry_run
  rescue LinkError
    unlink
    raise
  else
    ObserverPathnameExtension.total
  ensure
    optlink(mode) unless mode.dry_run
  end # link

  def remove_oldname_opt_record
    return unless oldname_opt_record and @oldname_opt_record.resolved_path == path
    @oldname_opt_record.unlink
    @oldname_opt_record.parent.rmdir_if_possible
    @oldname_opt_record = nil
  end

  def optlink(mode = OpenStruct.new)
    mode.overwrite = true
    make_relative_symlink(opt_record, path, mode)
    make_relative_symlink(oldname_opt_record, path, mode) if oldname_opt_record
  end

  def delete_pyc_files!; find { |pn| pn.delete if pn.extname == '.pyc' }; end

  def reconstruct_build_mode
    built_sets = {}
    path.find do |pn|
      if pn.tracked_mach_o?
        archset = pn.archs.sort
        if built_sets[archset] then built_sets[archset] += 1; else built_sets[archset] = 1; end
      end
    end
    max_count = built_sets.values.max
    built_set = built_sets.select{ |_, ct| ct == max_count }.keys.flatten.uniq
    built_set.length > 1 ? (built_set.all?{ |a| CPU.can_run? a } ? 'u' : 'x') : '1'
  end # reconstruct_build_mode

  private

  def resolve_any_conflicts(lnk, linkage_type, mode)
    return false unless lnk.symlink?
    tgt = lnk.resolved_path
    # Check lstat to ensure we have a directory, and not a symlink pointing at one (which would
    # need to be treated as a file).  In other words, only resolve one symlink.
    begin
      stat = tgt.lstat
    rescue Errno::ENOENT  # lnk is a broken symlink, so remove it.
      lnk.unlink unless mode.dry_run
      return false
    end
    if stat.directory?
      begin
        keg = Keg.for(tgt)
      rescue NotAKegError
        puts "Won’t resolve conflicts for symlink #{lnk} as it doesn’t resolve into the Cellar" if VERBOSE
        return false
      end
      lnk.unlink unless mode.dry_run
      keg.link_dir(tgt, mode) { linkage_type }
      return true
    end
  end # resolve_any_conflicts

  def make_relative_symlink(lnk, tgt, mode)
    _targ = mode.dry_run ? HOMEBREW_CELLAR/name/version_s/tgt.relative_path_from(path) : tgt
    if lnk.symlink? and lnk.resolved_path == _targ
      puts "Skipping; link already exists:  #{lnk}" if VERBOSE; return; end
    stats = lnk.lstat
    if mode.dry_run  # cf. git-clean -n: list files to delete, don't really link or delete
      if stats
        if mode.overwrite then puts "Would delete #{lnk}"
        else puts "Conflict!  #{lnk} already exists and is a #{(stats.ftype == 'link') \
                                                               ? "link to #{lnk.resolved_path}" \
                                                               : stats.ftype}"; end
      end
      puts "#{lnk} -> #{tgt}"
      return
    end
    lnk.rmtree if stats and mode.overwrite
    lnk.make_relative_symlink_to(tgt)
  rescue Errno::EEXIST => e
    if lnk.exists? then raise ConflictError.new(self, tgt.relative_path_from(path), lnk, e)
    elsif lnk.symlink? then lnk.unlink; retry; end
  rescue Errno::EACCES => e
    raise DirectoryNotWritableError.new(self, tgt.relative_path_from(path), lnk, e)
  rescue SystemCallError => e
    raise LinkError.new(self, tgt.relative_path_from(path), lnk, e)
  end # make_relative_symlink

  protected

  def make_path(dst, mode); if mode.dry_run then puts "Make #{dst}"; else; dst.mkpath; end; end

  # symlinks the contents of path/relative_dir recursively into #{HOMEBREW_PREFIX}/relative_dir
  def link_dir(relative_dir, mode)
    root = path/relative_dir
    return unless root.exists?
    root.find do |tgt|
      next if tgt == root
      (lnk = HOMEBREW_PREFIX/tgt.relative_path_from(path)).extend ObserverPathnameExtension
      yielded = yield (relpath = tgt.relative_path_from(root))
      unknown_linkage_msg = "Unknown linkage type “:#{yielded.to_s}” specified for #{relative_dir}/#{relpath}"
      if tgt.symlink? or tgt.file?
        next if tgt.basename == '.DS_Store' or
                tgt.realpath == lnk         or
                # Don't link pyc files because Python overwrites these cached object
                # files and next time brew wants to link, the pyc file is in the way.
               (tgt.extname == '.pyc' and tgt.to_s =~ %r{site-packages})
        case yielded
          when :info
            next if tgt.basename == 'dir'  # skip historical local 'dir' files
            make_relative_symlink(lnk, tgt, mode)
            if mode.dry_run then puts " -> info #{relative_dir}/#{relpath}"
            else lnk.install_info; end
          when :link, :link_tree, :skip_dirs then make_relative_symlink(lnk, tgt, mode)
          when :mkdir, :skip_this, nil       then next
          else raise LinkError.new(self, tgt, lnk, unknown_linkage_msg)
        end
      else # directory
        # no need to put .app bundles in the path, the user can just use
        # spotlight, or the open command and actual mac apps use an equivalent
        Find.prune if tgt.extname == '.app'
        case yielded
          when :info
            raise LinkError.new(self, tgt, lnk, ":info linkage specified for a directory:  #{relative_dir}/#{relpath}")
          when :link
            unless resolve_any_conflicts(lnk, :link, mode)
              make_relative_symlink(lnk, tgt, mode)
              Find.prune
            end
          when :link_tree
            unless lnk.directory? and not lnk.symlink?
              resolve_any_conflicts(lnk, :link_tree, mode) or make_path(lnk, mode)
            end
          when :mkdir
            unless lnk.directory? and not lnk.symlink?
              resolve_any_conflicts(lnk, :link, mode) or make_path(lnk, mode)
            end
          when :skip_dirs, :skip_this, nil then Find.prune
          else raise LinkError.new(self, tgt, lnk, unknown_linkage_msg)
        end
      end # tgt.type?
    end # do find
  end # link_dir
end # Keg
