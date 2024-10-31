require "extend/pathname"
require "keg_relocate"
require "formula_lock"
require "ostruct"

class Keg
  class AlreadyLinkedError < RuntimeError
    def initialize(keg)
      super <<-EOS.undent
          Cannot link #{keg.name}
          Another version is already linked: #{keg.linked_keg_record.resolved_path}
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
      "already exists. You may want to remove it:\n  rm '#{dst}'\n"
    else
      <<-EOS.undent
        is a symlink belonging to #{conflict.name}. You can unlink it:
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

  INFOFILE_RX = %r{info/([^.].*?\.info|dir)$}
  # locale-specific directories have the form language[_territory][.codeset][@modifier]
  LOCALEDIR_RX = /(locale|man)\/([a-z]{2}|C|POSIX)(_[A-Z]{2})?(\.[a-zA-Z\-0-9]+(@.+)?)?/
  TOP_LEVEL_DIRECTORIES = %w[bin etc include lib sbin share var Frameworks]
  PRUNEABLE_DIRECTORIES = %w[bin etc include lib sbin share Frameworks].map { |d| HOMEBREW_PREFIX/d }
  PRUNEABLE_DIRECTORIES << LINKDIR

  # These paths relative to the keg's share directory should always be real
  # directories in the prefix, never symlinks.
  SHARE_PATHS = %w[
    aclocal doc info locale man
    man/man1 man/man2 man/man3 man/man4
    man/man5 man/man6 man/man7 man/man8
    man/cat1 man/cat2 man/cat3 man/cat4
    man/cat5 man/cat6 man/cat7 man/cat8
    applications gnome gnome/help icons
    mime-info pixmaps sounds
  ]

  # During reïnstallations, the old keg must be temporarily renamed in order to remain in service –
  # otherwise, it becomes impossible to reïnstall anything used during brewing.
  REINSTALL_SUFFIX = '.being_reinstalled'

  # if path is a file in a keg then this will return the containing Keg object
  def self.for(path)
    path = path.realpath
    until path.root?  # this is the filesystem root, not Keg#root
      return Keg.new(path) if path.parent.parent == HOMEBREW_CELLAR
      path = path.parent.realpath # realpath() prevents .root? failing
    end
    raise NotAKegError, "#{path} is not inside a keg"
  end # Keg::for

  attr_reader :path, :name, :linked_keg_record, :opt_record
  protected :path

  # requires a Pathname object; a bare string won’t work
  def initialize(path)
    raise "#{path} is not a valid keg" unless path.parent.parent.realpath == HOMEBREW_CELLAR
    raise "#{path} is not a directory" unless path.directory?
    @path = path
    @name = path.parent.basename.to_s
    @linked_keg_record = LINKDIR/name
    @opt_record = OPTDIR/name
  end # initialize

#  def fname
#    opoo "Keg#fname is a deprecated alias for Keg#name and will be removed soon"
#    name
#  end

  def to_s; path.to_s; end
  alias_method :to_path, :to_s

  def rack; path.parent; end

  def root; path; end

  def inspect; "#<#{self.class.name}:#{path}>"; end

  def ==(other); instance_of?(other.class) && path == other.path; end
  alias_method :eql?, :==

  def hash; path.hash; end

  def abv; path.abv; end

  def directory?; path.directory?; end

  def exist?; path.exist?; end
  alias :exists? :exist?

  def /(other); path/other; end

  def join(*args); path.join(*args); end

  private

  def reinstall_nameflip
    (path.extname == REINSTALL_SUFFIX) ? (path.dirname/path.basename(REINSTALL_SUFFIX)).to_s : "#{path.to_s}#{REINSTALL_SUFFIX}"
  end

  public

  def rename(new_name = reinstall_nameflip)
    unlink if was_linked = linked?
    path.rename new_name            # rename the physical directory
    @path = Pathname.new new_name   # change our record of the name
    optlink                         # always regenerate the optlink
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

  def remove_opt_record
    opt_record.unlink
    opt_record.parent.rmdir_if_possible
  end

  def uninstall
    path.rmtree
    path.parent.rmdir_if_possible
    remove_opt_record if optlinked?
    remove_oldname_opt_record
  end # uninstall

  def unlink(mode = OpenStruct.new)
    ObserverPathnameExtension.reset_counts!
    dirs = []
    TOP_LEVEL_DIRECTORIES.map { |d| path.join(d) }.each do |dir|
      next unless dir.exist?
      dir.find do |src|
        dst = HOMEBREW_PREFIX + src.relative_path_from(path)
        dst.extend(ObserverPathnameExtension)
        dirs << dst if dst.directory? && !dst.symlink?
        # check whether the file to be unlinked is from the current keg first
        if dst.symlink? && src == dst.resolved_path
          if mode.dry_run
            puts dst
            Find.prune if src.directory?
            next
          end
          dst.uninstall_info if dst.to_s =~ INFOFILE_RX
          dst.unlink
          Find.prune if src.directory?
        end
      end
    end
    unless mode.dry_run
      remove_linked_keg_record if linked?
      dirs.reverse_each(&:rmdir_if_possible)
    end

    ObserverPathnameExtension.total
  end # unlink

  def lock
    FormulaLock.new(name).with_lock do
      if oldname_opt_record
        FormulaLock.new(oldname_opt_record.basename.to_s).with_lock { yield }
      else
        yield
      end
    end
  end # lock

  def completion_installed?(shell)
    dir = case shell
          when :bash then path.join("etc", "bash_completion.d")
          when :zsh  then path.join("share", "zsh", "site-functions")
          when :fish then path.join("share", "fish", "vendor_completions.d")
          end
    dir && dir.directory? && dir.children.any?
  end # completion_installed?

  def plist_installed?; Dir["#{path}/*.plist"].any?; end

  def python_site_packages_installed?; (path/'lib/python2.7/site-packages').directory?; end

  def python_pth_files_installed?; Dir["#{path}/lib/python2.7/site-packages/*.pth"].any?; end

  def app_installed?; Dir["#{path}/{,libexec/}*.app"].any?; end

  def elisp_installed?; Dir["#{path}/share/emacs/site-lisp/**/*.el"].any?; end

  def version
    require "pkg_version"
    PkgVersion.parse(path.basename.to_s)
  end

  def find(*args, &block); path.find(*args, &block); end

  def oldname_opt_record
    @oldname_opt_record ||= \
      OPTDIR.subdirs.detect do |dir|
        dir.symlink? and dir != opt_record and path.parent == dir.resolved_path.parent
      end if OPTDIR.directory?
  end # oldname_opt_record

  def link(mode = OpenStruct.new)
    raise AlreadyLinkedError.new(self) if linked_keg_record.directory?

    ObserverPathnameExtension.reset_counts!

    # yeah indeed, you have to force anything you need in the main tree into
    # these dirs REMEMBER that *NOT* everything needs to be in the main tree
    link_dir("etc", mode) { :mkpath }
    link_dir("bin", mode) { :skip_dir }
    link_dir("sbin", mode) { :skip_dir }
    link_dir("include", mode) { :link }

    link_dir("share", mode) do |relative_path|
      case relative_path.to_s
      when "locale/locale.alias" then :skip_file
      when INFOFILE_RX then :info
      when LOCALEDIR_RX then :mkpath
      when *SHARE_PATHS then :mkpath
      when /^icons\/.*\/icon-theme\.cache$/ then :skip_file
      # all icons subfolders should also mkpath
      when /^icons\// then :mkpath
      when /^zsh/ then :mkpath
      when /^fish/ then :mkpath
      else :link
      end
    end

    link_dir("lib", mode) do |relative_path|
      case relative_path.to_s
      when "charset.alias" then :skip_file
      # pkg-config database gets explicitly created
      when "pkgconfig" then :mkpath
      # cmake database gets explicitly created
      when "cmake" then :mkpath
      # lib/language folders also get explicitly created
      when "dtrace" then :mkpath
      when /^gdk-pixbuf/ then :mkpath
      when "ghc" then :mkpath
      when /^gio/ then :mkpath
      when "lua" then :mkpath
      when /^mecab/ then :mkpath
      when /^node/ then :mkpath
      when /^ocaml/ then :mkpath
      when /^perl5/ then :mkpath
      when "php" then :mkpath
      when /^python[23]\.\d/ then :mkpath
      when /^R/ then :mkpath
      when /^ruby/ then :mkpath
      # Everything else is symlinked to the cellar
      else :link
      end
    end

    link_dir("Frameworks", mode) do |relative_path|
      # Frameworks contain symlinks pointing into a subdir, so we have to use
      # the :link strategy. However, for Foo.framework and
      # Foo.framework/Versions we have to use :mkpath so that multiple formulae
      # can link their versions into it and `brew [un]link` works.
      if relative_path.to_s =~ /[^\/]*\.framework(\/Versions)?$/
        :mkpath
      else
        :link
      end
    end

    unless mode.dry_run
      make_relative_symlink(linked_keg_record, path, mode)
      optlink(mode)
    end
  rescue LinkError
    unlink
    raise
  else
    ObserverPathnameExtension.total
  end # link

  def remove_oldname_opt_record
    return unless oldname_opt_record
    return unless oldname_opt_record.resolved_path == path
    @oldname_opt_record.unlink
    @oldname_opt_record.parent.rmdir_if_possible
    @oldname_opt_record = nil
  end # remove_oldname_opt_record

  def optlink(mode = OpenStruct.new)
    opt_record.delete if opt_record.symlink? || opt_record.exist?
    make_relative_symlink(opt_record, path, mode)
    if oldname_opt_record
      oldname_opt_record.delete
      make_relative_symlink(oldname_opt_record, path, mode)
    end
  end # optlink

  def delete_pyc_files!; find { |pn| pn.delete if pn.extname == ".pyc" }; end

  private

  def resolve_any_conflicts(dst, mode)
    return unless dst.symlink?
    src = dst.resolved_path
    # src itself may be a symlink, so check lstat to ensure we are dealing with
    # a directory, and not a symlink pointing at a directory (which needs to be
    # treated as a file). In other words, we only want to resolve one symlink.
    begin
      stat = src.lstat
    rescue Errno::ENOENT
      # dst is a broken symlink, so remove it.
      dst.unlink unless mode.dry_run
      return
    end
    if stat.directory?
      begin
        keg = Keg.for(src)
      rescue NotAKegError
        puts "Won't resolve conflicts for symlink #{dst} as it doesn't resolve into the Cellar" if VERBOSE
        return
      end
      dst.unlink unless mode.dry_run
      keg.link_dir(src, mode) { :mkpath }
      return true
    end
  end # resolve_any_conflicts

  def make_relative_symlink(dst, src, mode)
    if dst.symlink? && src == dst.resolved_path
      puts "Skipping; link already exists: #{dst}" if VERBOSE
      return
    end
    if mode.dry_run
      # cf. git-clean -n: list files to delete, don't really link or delete
      if mode.overwrite
        if dst.symlink?
          puts "#{dst} -> #{dst.resolved_path}"
        elsif dst.exist?
          puts dst
        end
        return
      end # is mode “overwrite”?
      # list all link targets
      puts dst
      return
    end
    dst.delete if mode.overwrite && (dst.exist? || dst.symlink?)
    dst.make_relative_symlink(src)
  rescue Errno::EEXIST => e
    if dst.exist?
      raise ConflictError.new(self, src.relative_path_from(path), dst, e)
    elsif dst.symlink?
      dst.unlink
      retry
    end # is dst real?
  rescue Errno::EACCES => e
    raise DirectoryNotWritableError.new(self, src.relative_path_from(path), dst, e)
  rescue SystemCallError => e
    raise LinkError.new(self, src.relative_path_from(path), dst, e)
  end # make_relative_symlink

  protected

  # symlinks the contents of path+relative_dir recursively into #{HOMEBREW_PREFIX}/relative_dir
  def link_dir(relative_dir, mode)
    root = path+relative_dir
    return unless root.exist?
    root.find do |src|
      next if src == root
      dst = HOMEBREW_PREFIX + src.relative_path_from(path)
      dst.extend ObserverPathnameExtension

      if src.symlink? || src.file?
        Find.prune if File.basename(src) == ".DS_Store"
        Find.prune if src.realpath == dst
        # Don't link pyc files because Python overwrites these cached object
        # files and next time brew wants to link, the pyc file is in the way.
        if src.extname == ".pyc" && src.to_s =~ /site-packages/
          Find.prune
        end

        case yield src.relative_path_from(root)
        when :skip_file, nil
          Find.prune
        when :info
          next if File.basename(src) == "dir" # skip historical local 'dir' files
          make_relative_symlink dst, src, mode
          dst.install_info
        else
          make_relative_symlink dst, src, mode
        end
      elsif src.directory?
        # if the dst dir already exists, then great! walk the rest of the tree tho
        next if dst.directory? && !dst.symlink?
        # no need to put .app bundles in the path, the user can just use
        # spotlight, or the open command and actual mac apps use an equivalent
        Find.prune if src.extname == ".app"

        case yield src.relative_path_from(root)
        when :skip_dir
          Find.prune
        when :mkpath
          dst.mkpath unless resolve_any_conflicts(dst, mode)
        else
          unless resolve_any_conflicts(dst, mode)
            make_relative_symlink dst, src, mode
            Find.prune
          end
        end
      end
    end
  end # link_dir
end # Keg
