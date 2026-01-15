require 'formula'
require 'keg'
require 'bottles'
require 'thread'

module Homebrew
  def cleanup
    if ARGV.named.empty?
      cleanup_cellar
      cleanup_cache
      cleanup_checkpoints
      cleanup_logs
      unless ARGV.dry_run?
        cleanup_lockfiles
        rm_DS_Store
      end
    else
      ARGV.formulae.each do |f|
        cleanup_formula(f) if ARGV.resolved_formulae.include?(f)
        cleanup_cache(f)
        cleanup_checkpoints(f)
        cleanup_logs(f)
      end # each formula |f|
    end # ARGV.named is not empty
  end # cleanup

  def cleanup_cache(f = nil)
    return unless HOMEBREW_CACHE.directory?
    HOMEBREW_CACHE.children.each do |path|
      if f then next unless path.basename.to_s.starts_with?(f.name); end
      if prune?(path)
        if path.file? then cleanup_path(path) { path.unlink }
        elsif path.directory? and path.to_s.includes?('--') then cleanup_path(path) { FileUtils.rm_rf path }; end
        next
      end
      next unless path.file?
      file = path
      if Pathname::BOTTLE_EXTNAME_RX === file.to_s then version = bottle_resolve_version(file) rescue file.version
      else version = file.version; end
      next unless version
      next unless (name = file.basename.to_s[/(.*)-(?:#{Regexp.escape(version.to_s)})/, 1])
      next unless HOMEBREW_CELLAR.directory?
      begin
        f = Formulary.from_rack(HOMEBREW_CELLAR/name)
      rescue FormulaUnavailableError, TapFormulaAmbiguityError
        next
      end
      file_is_stale = (PkgVersion === version ? (f.pkg_version > version) : (f.version > version))
      if file_is_stale or ARGV.switch?('s') and not f.installed? or bottle_file_outdated?(f, file)
        cleanup_path(file) { file.unlink }
      end
    end # each cache child |path|
  end # cleanup_cache

  def cleanup_cellar; Formula.installed.each{ |formula| cleanup_formula formula }; end

  def cleanup_checkpoints(f = nil)
    return unless CHECKPOINTS.exists?
    if f then
      return unless (CHECKPOINTS/f.name).exists?
      cleanup_path(CHECKPOINTS/f.name) { (CHECKPOINTS/f.name).rmtree }
    else cleanup_path(CHECKPOINTS) { CHECKPOINTS.rmtree }; end
  end # cleanup_checkpoints

  def cleanup_formula(f)
    if f.installed?
      eligible_kegs = f.rack.subdirs.map{ |d| Keg.new(d) }.select{ |k| f.pkg_version > k.version }
      if eligible_kegs.any? && eligible_for_cleanup?(f) then eligible_kegs.each{ |keg| cleanup_keg(keg) }
      else eligible_kegs.each{ |keg| opoo "Skipping (old) keg-only:  #{keg}" }; end
    elsif (pn = f.linked_keg.resolved_path).directory? \
          or (f.pinned? and (pn = (PINDIR/f.name).resolved_path).directory?) \
          or (pn = f.opt_prefix.resolved_path).directory?  # Clean up the others.
      eligible_kegs = f.rack.subdirs.select{ |d| d != pn }.map{ |d| Keg.new(d) }
      if eligible_kegs.any? and eligible_for_cleanup?(f) then eligible_kegs.each{ |keg| cleanup_keg(keg) }
      else eligible_kegs.each{ |keg| opoo "Skipping (old) keg-only:  #{keg}" }; end
    elsif f.rack.subdirs.length == 1  # If only one version is installed, don’t complain that we can’t tell which one to keep.
      opoo "Skipping #{f.full_name}:  Most recent version #{f.pkg_version} not installed"
    else raise MultipleVersionsInstalledError.new(f.full_name); end
  end # cleanup_formula

  def cleanup_keg(keg)
    if keg.linked? then opoo "Skipping (old) #{keg} due to it being linked"
    else cleanup_path(keg) { keg.uninstall }; end
  end

  def cleanup_lockfiles
    return unless HOMEBREW_FORMULA_CACHE.directory?
    candidates = HOMEBREW_FORMULA_CACHE.children
    lockfiles  = candidates.select { |f| f.file? && f.extname == '.brewing' }
    lockfiles.each do |file|
      next unless file.readable?
      file.open.flock(File::LOCK_EX | File::LOCK_NB) && file.unlink
    end
  end # cleanup_lockfiles

  def cleanup_logs(f = nil)
    return unless HOMEBREW_LOGS.directory?
    HOMEBREW_LOGS.subdirs.each do |dir|
      if f then next unless dir.basename == f.name; end
      cleanup_path(dir) { dir.rmtree } if prune?(dir, :days_default => 14)
    end
  end

  def cleanup_path(path)
    if ARGV.dry_run? then puts "Would remove: #{path} (#{path.abv})"
    else puts "Removing: #{path}... (#{path.abv})"; yield; end
  end

  def eligible_for_cleanup?(formula)
    # It used to be the case that keg-only kegs couldn’t be cleaned up, because older brews were built against the full path to the
    # keg-only keg.  Then we introduced the opt symlink, and built against that instead.  So provided no brew exists that was built
    # against an old-style keg-only keg, we can remove it.
    if not formula.keg_only? or ARGV.force? then true
    elsif formula.opt_prefix.directory?
      # SHA records were added to INSTALL_RECEIPTs the same day as opt symlinks
      Formula.installed.select{ |f|
        f.deps.any?{ |d| d.to_formula.full_name == formula.full_name rescue d.name == formula.name }
      }.all?{ |f| f.rack.subdirs.all?{ |keg| Tab.for_keg(keg).git_head_SHA1 } }
    end
  end # eligible_for_cleanup?

  def prune?(path, options = {})
    @time ||= Time.now
    path_modified_time = path.mtime
    days_default = options[:days_default]
    prune = ARGV.value 'prune'
    return true if prune == 'all'
    prune_time = prune ? @time - 60 * 60 * 24 * prune.to_i : days_default ? @time - 60 * 60 * 24 * days_default.to_i : nil
    return false unless prune_time
    path_modified_time < prune_time
  end

  def rm_DS_Store
    paths = Queue.new
    %w[Cellar Frameworks Library bin etc include lib opt sbin share var].
      map{ |p| HOMEBREW_PREFIX/p }.each{ |p| paths << p if p.exists? }
    workers = (0...CPU.cores).map do
      Thread.new do
        begin
          while p = paths.pop(true)
            silent_system 'find', p, '-name', '.DS_Store', '-delete'
          end
        rescue ThreadError # ignore empty queue error
        end
      end # thread definition block
    end # map worker threads
    workers.map(&:join)
  end # rm_DS_Store
end # Homebrew
