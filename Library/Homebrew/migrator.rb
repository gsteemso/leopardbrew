require 'formula'
require 'formula/lock'
require 'keg'
require 'tab'
require 'tap_migrations'

class Migrator
  class MigrationNeededError < RuntimeError
    def initialize(formula)
      super <<-EOS.undent
        #{formula.oldname} was renamed to #{formula.name} and needs to be migrated.
        Please run `brew migrate #{formula.oldname}`
      EOS
    end
  end # Migrator::MigrationNeededError

  class MigratorNoOldnameError < RuntimeError
    def initialize(formula); super "#{formula.name} doesn’t replace any formula."; end
  end

  class MigratorNoOldpathError < RuntimeError
    def initialize(formula); super "#{HOMEBREW_CELLAR/formula.oldname} doesn’t exist."; end
  end

  class MigratorDifferentTapsError < RuntimeError
    def initialize(formula, tap)
      msg = if CORE_OWNERS.include? tap
              "Please use the bare #{formula.oldname} form to name the formula."
            else
              user, repo = tap.split('/'); repo.sub!('homebrew-', '')
              "Please use the fully-qualified #{user}/#{repo}/#{formula.oldname} form to name the formula."
            end if tap

      super <<-EOS.undent.rewrap
        #{formula.name} from #{formula.tap} is given, but the old name #{formula.oldname}
        was installed from #{tap ? tap : 'path or url'}.

        #{msg}

        To force migrate use `brew migrate --force #{formula.oldname}`.
      EOS
    end
  end

  # instance of new‐name {Formula}; new name; new‐name rack {Pathname}; old name; old‐name rack {Pathname}
  attr_reader :formula, :newname, :new_rack, :oldname, :old_rack

  # old‐name {Tab}s; old‐name tap
  attr_reader :old_tabs, :old_tap

  # old‐name linked {Keg}; old‐name keg link {Pathname}; old‐name opt/ {Pathname}; new‐name linked keg {Pathname}
  attr_reader :old_linked_keg, :old_linked_keg_record, :old_opt_record, :new_linked_keg_record

  # new‐name pin {Pathname}; old‐name pin {Pathname}; resolved {Pathname} to old‐name pin
  attr_reader :new_pin_record, :old_pin_record, :old_pin_link_record

  def initialize(formula)
    @formula = formula
    @newname = formula.name
    @new_rack = HOMEBREW_CELLAR/newname
    raise MigratorNoOldnameError.new(formula) unless @oldname = formula.oldname
    raise MigratorNoOldpathError.new(formula) unless (@old_rack = HOMEBREW_CELLAR/oldname).exists?
    @old_tabs = old_rack.subdirs.map { |d| Tab.for_keg(Keg.new(d)) }
    @old_tap = old_tabs.first.tap
    raise MigratorDifferentTapsError.new(formula, old_tap) unless ARGV.force? or from_same_taps?
    if @old_linked_keg = get_linked_old_linked_keg
      @old_linked_keg_record = old_linked_keg.linked_keg_record if old_linked_keg.linked?
      @old_opt_record = old_linked_keg.opt_record if old_linked_keg.optlinked?
      @new_linked_keg_record = HOMEBREW_CELLAR/"#{newname}/#{File.basename(old_linked_keg)}"
    end
    @new_pin_record = PINDIR/newname
    @old_pin_record = PINDIR/oldname
    @pinned = old_pin_record.symlink?
    @old_pin_link_record = old_pin_record.readlink if @pinned
  end # Migrator#initialize

  # Fix INSTALL_RECEIPTS for tap-migrated formula.
  def fix_tabs
    old_tabs.each do |tab|
      tab.source['tap'] = formula.tap
      tab.write
    end
  end # Migrator#fix_tabs

  def from_same_taps?
    if formula.tap == old_tap
      true
    # Homebrew didn't use to update tabs while performing tap-migrations,
    # so there can be INSTALL_RECEIPT's containing wrong information about
    # tap (tap is Homebrew/homebrew if installed formula migrates to a tap), so
    # we check if there is an entry about oldname migrated to tap and if
    # newname's tap is the same as tap to which oldname migrated, then we
    # can perform migrations and the taps for oldname and newname are the same.
    elsif TAP_MIGRATIONS && (rec = TAP_MIGRATIONS[formula.oldname]) \
        && rec == formula.tap.sub('homebrew-', '') && old_tap == 'Homebrew/homebrew'
      fix_tabs
      true
    elsif formula.tap
      false
    end
  end # Migrator#from_same_taps?

  def get_linked_old_linked_keg
    kegs = old_rack.subdirs.map { |d| Keg.new(d) }
    kegs.detect(&:linked?) || kegs.detect(&:optlinked?)
  end

  def pinned?; @pinned; end

  def migrate
    if new_rack.exists?
      onoe "#{new_rack} already exists; remove it manually and run brew migrate #{oldname}."
      return
    end

    begin
      oh1 "Migrating #{TTY.green}#{oldname}#{TTY.white} to #{TTY.green}#{newname}#{TTY.reset}"
      lock
      unlink_oldname
      move_to_new_directory
      repin
      link_oldname_rack
      link_oldname_opt
      link_newname unless old_linked_keg.nil?
      update_tabs
    rescue Interrupt
      ignore_interrupts { backup_oldname }
    rescue Exception => e
      onoe 'Error occured while migrating.'
      puts e
      puts e.backtrace if DEBUG
      puts 'Backing up...'
      ignore_interrupts { backup_oldname }
    ensure
      unlock
    end
    clear_out_locks
  end # Migrator#migrate

  # move everything from Cellar/oldname to Cellar/newname
  def move_to_new_directory
    puts "Moving to:  #{new_rack}"
    FileUtils.mv(old_rack, new_rack)
  end

  def repin
    if pinned?
      # old_pin_record is a relative symlink and when we try to to read it
      # from <dir> we actually try to find the directory
      # <dir>/../<...>/../Cellar/name/version.
      # To repin a formula we need to update the link such that it points to
      # the right directory.
      # NOTE: old_pin_record.realpath.sub(oldname, newname) is unacceptable
      # here, because it resolves every symlink for old_pin_record and then
      # substitutes oldname with newname. It breaks things like
      # Pathname#make_relative_symlink, where Pathname#relative_path_from
      # is used to find relative path from source to destination parent and
      # it assumes no symlinks.
      src_oldname = old_pin_record.dirname.join(old_pin_link_record).expand_path
      new_pin_record.make_relative_symlink(src_oldname.sub(oldname, newname))
      old_pin_record.delete
    end # pinned?
  end # Migrator#repin

  def unlink_oldname
    oh1 "Unlinking #{TTY.green}#{oldname}#{TTY.reset}"
    old_rack.subdirs.each do |d|
      keg = Keg.new(d)
      keg.unlink
    end
  end # Migrator#unlink_oldname

  def link_newname
    oh1 "Linking #{TTY.green}#{newname}#{TTY.reset}"
    new_keg = Keg.new(new_linked_keg_record)

    # If {old_keg} wasn’t linked, or {formula} is keg‐only, we just optlink a keg.
    # If {old_keg} was neither optlinked nor linked, we don’t call this method in the first place.
    if formula.keg_only? or not old_linked_keg_record
      begin
        new_keg.optlink
      rescue Keg::LinkError => e
        onoe "Failed to create #{formula.opt_prefix}"
        raise
      end
      return
    end # keg‐only, or old_keg was not linked

    new_keg.remove_linked_keg_record if new_keg.linked?

    begin
      new_keg.link
    rescue Keg::ConflictError => e
      onoe "Error while executing `brew link` step on #{newname}", e, '', 'Possible conflicting files are:'
      mode = OpenStruct.new(:dry_run => true, :overwrite => true)
      new_keg.link(mode)
      raise
    rescue Keg::LinkError => e
      onoe 'Error while linking', e, '', 'You can try again using:', "    brew link #{formula.name}"
    rescue Exception => e
      onoe 'An unexpected error occurred during linking', e
      puts e.backtrace if DEBUG
      ignore_interrupts { new_keg.unlink }
      raise
    end
  end # Migrator#link_newname

  # Link keg to opt if it was linked before migrating.
  def link_oldname_opt
    if old_opt_record
      old_opt_record.delete if old_opt_record.symlink?
      old_opt_record.make_relative_symlink(new_linked_keg_record)
    end
  end # Migrator#link_oldname_opt

  # After migration every INSTALL_RECEIPT.json has wrong path to the formula
  # so we must update INSTALL_RECEIPTs
  def update_tabs
    new_tabs = new_rack.subdirs.map { |d| Tab.for_keg(Keg.new(d)) }
    new_tabs.each do |tab|
      tab.source['path'] = formula.path.to_s if tab.source['path']
      tab.write
    end
  end # Migrator#update_tabs

  # Remove opt/oldname link if it belongs to newname.
  def unlink_oldname_opt
    return unless old_opt_record
    if old_opt_record.symlink? and old_opt_record.exists? \
        and new_linked_keg_record.exists? \
        and new_linked_keg_record.realpath == old_opt_record.realpath
      old_opt_record.unlink
      old_opt_record.parent.rmdir_if_possible
    end
  end # Migrator#unlink_oldname_opt

  # Remove old_rack if it exists
  def link_oldname_rack
    old_rack.delete if old_rack.symlink? or old_rack.exists?
    old_rack.make_relative_symlink(formula.rack)
  end

  # Remove Cellar/oldname link if it belongs to newname.
  def unlink_oldname_rack
    if old_rack.symlink? and (not old_rack.exists? or (formula.rack.exists? and formula.rack.realpath == old_rack.realpath))
      old_rack.unlink
    end
  end

  # Back everything up in case errors occur while migrating.
  def backup_oldname
    unlink_oldname_opt
    unlink_oldname_rack
    backup_oldname_rack
    backup_old_tabs

    if pinned? and not old_pin_record.symlink?
      src_oldname = old_pin_record.dirname.join(old_pin_link_record).expand_path
      old_pin_record.make_relative_symlink(src_oldname)
      new_pin_record.delete
    end

    if new_rack.exists?
      new_rack.subdirs.each do |d|
        newname_keg = Keg.new(d)
        newname_keg.unlink
        newname_keg.uninstall
      end # do each subdir |d|
    end # new cellar exists?

    unless old_linked_keg.nil?
      # The keg used to be linked and when we backup everything we restore
      # Cellar/oldname, the target also gets restored, so we are able to
      # create a keg using its old path
      if old_linked_keg_record
        begin
          old_linked_keg.link
        rescue Keg::LinkError
          old_linked_keg.unlink
          raise
        rescue Keg::AlreadyLinkedError
          old_linked_keg.unlink
          retry
        end
      else # no old linked keg record
        old_linked_keg.optlink
      end # old linked keg record?
    end # old linked keg nil?
  end # Migrator#backup_oldname

  def backup_oldname_rack; FileUtils.mv(new_rack, old_rack) unless old_rack.exists?; end

  def backup_old_tabs; old_tabs.each(&:write); end

  def lock
    @newname_lock = FormulaLock.new newname
    @oldname_lock = FormulaLock.new oldname
    @newname_lock.lock
    @oldname_lock.lock
  end # Migrator#lock

  def unlock
    @newname_lock.unlock
    @oldname_lock.unlock
  end

  def clear_out_locks
    @newname_lock.delete
    @oldname_lock.delete
  end
end # Migrator
