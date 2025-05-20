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
    attr_reader :keg, :src, :dst
    def initialize(keg, src, dst, cause)
      @src = src
      @dst = dst
      @keg = keg
      @cause = cause
      super(cause.message)
      set_backtrace(cause.backtrace)
    end # initialize
  end # LinkError

  class ConflictError < LinkError
    def suggestion
      conflict = Keg.for(dst)
    rescue NotAKegError, Errno::ENOENT
      "already exists.  You may want to remove it:\n    rm '#{dst}'\n"
    else <<-EOS.undent
        is a symlink belonging to #{conflict.name}.  You can unlink it:
            brew unlink #{conflict.name}

      EOS
    end # suggestion

    def to_s
      s = []
      s << "Could not symlink #{src}"
      s << "Target #{dst}" << suggestion
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
      Could not symlink #{src}
      #{dst.dirname} is not writable.
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
  MAN_RX = %r{^man(/(cat|man)\d?[^/]{0,3})?$}
  MANPAGE_RX = %r{^man(/(cat|man)\d?[^/]{0,3})?}

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
    (path/Tab::FILENAME).file? ? Formulary.from_keg(path) : Formulary.from_rack(rack)
  end

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
      dir.find do |src|
        dst = HOMEBREW_PREFIX/src.relative_path_from(path)
        dst.extend(ObserverPathnameExtension)
        next unless dst.exists?
        if dst.symlink? and src == dst.resolved_path  # only unlink a file from the current keg
          if mode.dry_run then puts dst
          else
            dst.uninstall_info if dst.to_s =~ INFOFILE_RX
            dst.unlink
          end
        end
        if src.directory? then if src.symlink? then Find.prune; else dirs << dst; end; end
      end # find |src|
    end # each top‐level directory |dir|
    remove_linked_keg_record if linked? and not mode.dry_run
    dirs.reverse_each do |d|
      if mode.dry_run then puts "Would attempt to remove #{d}"; else d.rmdir_if_possible; end
    end

    ObserverPathnameExtension.total
  end # unlink

  def lock
    FormulaLock.new(name).with_lock do
      if oldname_opt_record then FormulaLock.new(oldname_opt_record.basename.to_s).with_lock { yield }
      else yield; end
    end
  end # lock

  def completion_installed?(shell)
    dir = case shell
            when :bash then path/'etc/bash_completion.d'
            when :fish then path/'share/fish/vendor_completions.d'
            when :zsh  then path/'share/zsh/site-functions'
          end
    dir and dir.directory? and dir.children.any?
  end # completion_installed?

  def plist_installed?; Dir["#{path}/*.plist"].any?; end

  def python_site_packages_installed?; (path/'lib/python2.7/site-packages').directory?; end

  def python_pth_files_installed?; Dir["#{path}/lib/python2.7/site-packages/*.pth"].any?; end

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

    link_dir('Frameworks',            mode) do |relative_path|
        # Frameworks contain symlinks pointing into a subdir, so we have to use :link.  However, for
        # Foo.framework and Foo.framework/Versions we have to use :mkpath so that multiple formula
        # versions can link into it and still have `brew [un]link` work.
        (relative_path.to_s =~ %r{[^/]*\.framework(/Versions)?$}) \
                                            ? :mkdir \
                                            : :link
      end # link_dir Frameworks
    link_dir('bin',     mode) {               :skip_dirs }
    link_dir('etc',     mode) {               :link_tree }
    link_dir('include', mode) {               :link      }
    link_dir('lib',     mode) do |relative_path|
        case relative_path.to_s
          when 'charset.alias'           then :skip_this
          # cmake & pkg-config databases, plus lib/<language> folders, get explicitly created
          when 'cmake', 'dtrace', 'ghc', 'lua', 'php', 'pkgconfig',
               %r{^(R|gdk-pixbuf|gio|mecab|node|ocaml|perl5|python[23]\.\d+|ruby)[^/]*$}
                                         then :mkdir
          when %r{^(cmake|dtrace|ghc|lua|php|pkgconfig|((R|gdk-pixbuf|gio|mecab|node|ocaml|perl5|python[23]\.\d+|ruby)[^/]*))/}
                                         then :link
                                         else :link   # Everything else is symlinked to the cellar
        end
      end # link_dir lib
    link_dir('sbin',    mode) {               :skip_dirs }
    link_dir('share',   mode) do |relative_path|
        case relative_path.to_s
          when %r{^icons/.*/icon-theme\.cache$},
               'locale/locale.alias'     then :skip_this
          when INFOFILE_RX               then :info
          when 'fish', 'ri', *SHARE_PATHS,
               'zsh', MAN_RX             then :mkdir
          when %r{^(fish/vendor_completions.d|icons|zsh/site_functions)/}, LOCALEDIR_RX
                                         then :link_tree
          when %r{^(ri|#{SHARE_PATHS * '|'})/},
               MANPAGE_RX                then :link
          when %r{^(fish|zsh)/}          then :link
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

  private

  def resolve_any_conflicts(dst, linkage_type, mode)
    return false unless dst.symlink?
    src = dst.resolved_path
    # Check lstat to ensure we have a directory, and not a symlink pointing at one (which would
    # need to be treated as a file).  In other words, only resolve one symlink.
    begin
      stat = src.lstat
    rescue Errno::ENOENT  # dst is a broken symlink, so remove it.
      dst.unlink unless mode.dry_run
      return false
    end
    if stat.directory?
      begin
        keg = Keg.for(src)
      rescue NotAKegError
        puts "Won’t resolve conflicts for symlink #{dst} as it doesn’t resolve into the Cellar" if VERBOSE
        return false
      end
      dst.unlink unless mode.dry_run
      keg.link_dir(src, mode) { linkage_type }
      return true
    end
  end # resolve_any_conflicts

  def make_relative_symlink(dst, src, mode)
    _src = mode.dry_run ? HOMEBREW_CELLAR/name/version_s/src.relative_path_from(path) : src
    if dst.symlink? and dst.resolved_path == _src
      puts "Skipping; link already exists:  #{dst}" if VERBOSE; return; end
    stats = dst.lstat
    if mode.dry_run  # cf. git-clean -n: list files to delete, don't really link or delete
      if stats
        if mode.overwrite then puts "Would delete #{dst}"
        else puts "Conflict!  #{dst} already exists and is a #{(stats.ftype == 'link') ? "link to #{dst.resolved_path}" \
                                                                                       : stats.ftype}"; end
      end
      puts "#{dst} -> #{_src}"
      return
    end
    dst.rmtree if stats and mode.overwrite
    dst.make_relative_symlink_to(src)
  rescue Errno::EEXIST => e
    if dst.exists? then raise ConflictError.new(self, src.relative_path_from(path), dst, e)
    elsif dst.symlink? then dst.unlink; retry; end
  rescue Errno::EACCES => e
    raise DirectoryNotWritableError.new(self, src.relative_path_from(path), dst, e)
  rescue SystemCallError => e
    raise LinkError.new(self, src.relative_path_from(path), dst, e)
  end # make_relative_symlink

  protected

  def make_path(dst, mode); if mode.dry_run then puts "Make #{dst}"; else; dst.mkpath; end; end

  # symlinks the contents of path/relative_dir recursively into #{HOMEBREW_PREFIX}/relative_dir
  def link_dir(relative_dir, mode)
    root = path/relative_dir
    return unless root.exists?
    root.find do |src|
      next if src == root
      dst = HOMEBREW_PREFIX/src.relative_path_from(path)
      dst.extend ObserverPathnameExtension
      yielded = yield (relpath = src.relative_path_from(root))
      if src.symlink? or src.file?
        next if src.basename == '.DS_Store' or
                src.realpath == dst         or
                # Don't link pyc files because Python overwrites these cached object
                # files and next time brew wants to link, the pyc file is in the way.
               (src.extname == '.pyc' and src.to_s =~ %r{site-packages})
        case yielded
          when :info
            next if src.basename == 'dir'  # skip historical local 'dir' files
            make_relative_symlink(dst, src, mode)
            if mode.dry_run then puts " -> info #{relative_dir}/#{relpath}"
            else dst.install_info; end
          when :link, :link_tree, :skip_dirs
            make_relative_symlink(dst, src, mode)
          when :mkdir, :skip_this, nil
            next
          else
            raise RuntimeError, "Unknown linkage type “#{yielded.inspect}” specified, at #{relative_dir}/#{relpath}"
        end
      else # directory
        # no need to put .app bundles in the path, the user can just use
        # spotlight, or the open command and actual mac apps use an equivalent
        Find.prune if src.extname == '.app'
        case yielded
          when :info
            raise RuntimeError, ":info linkage specified for a directory, at #{relative_dir}/#{relpath}"
          when :link
            unless resolve_any_conflicts(dst, :link, mode)
              make_relative_symlink(dst, src, mode)
              Find.prune
            end
          when :link_tree
            unless dst.directory? and not dst.symlink?
              resolve_any_conflicts(dst, :link_tree, mode) or make_path(dst, mode)
            end
          when :mkdir
            unless dst.directory? and not dst.symlink?
              resolve_any_conflicts(dst, :link, mode) or make_path(dst, mode)
            end
          when :skip_dirs, :skip_this, nil
            Find.prune
          else
            raise RuntimeError, "Unknown linkage type “#{yielded.inspect}” specified, at #{relative_dir}/#{relpath}"
        end
      end # src.type?
    end # do find
  end # link_dir
end # Keg
