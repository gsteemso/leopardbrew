require "keg"
require "formula"
require "migrator"

module Homebrew
  def uninstall
    raise KegUnspecifiedError if ARGV.named.empty?
    f = nil
    unless ARGV.force? # remove active version only
      begin
        kegs = ARGV.kegs
      rescue FormulaNotInstalledError => e  # Only issued by ARGV#kegs if empty rack encountered.
        (HOMEBREW_CELLAR/e.name).rmtree
        [LINKDIR, PINDIR, OPTDIR].each do |d|
          link = d/e.name
          link.unlink if link.symlink?
        end
        puts <<-_.undent.rewrap
            Missing installation “#{e.name}” detected and cleaned up.  Depending how it got that
            way, stray symlinks may still exist under #{HOMEBREW_PREFIX}.
          _
        kegs = []
      end
      kegs.each do |keg|
        was_linked = keg.linked?
        keg.lock do
          puts "Uninstalling #{keg}... (#{keg.abv})"
          if f = attempt_from_keg(keg)
            f.unpin rescue nil
            f.uninsinuate if f.uninsinuate_defined?  # Repeat this later, so helper scripts can
                                                     # self‐delete if the rack has gone.
          end
          keg.unlink
          keg.uninstall  # this also deletes the whole rack, if it’s empty
          rack = keg.rack
          if rack.directory?
            if (dirs = rack.subdirs) != []
              # hook up the next keg in line
              next_keg = dirs.map{ |d| Keg.new(d) }.max_by(&:version)
              next_keg.optlink
              next_keg.link if was_linked
              if f = attempt_from_keg(next_keg) then f.insinuate; end
              # report on whatever’s still installed
              versions = dirs.map(&:basename)
              verb = versions.length == 1 ? 'is' : 'are'
              puts "#{keg.name} #{versions.list} #{verb} still installed."
              puts "Remove them all with `brew uninstall --force #{keg.name}`."
            else # rack still exists even though empty of subdirectories – fix that:
              rack.rm_rf
            end
          end # rack is a directory
        end # keg lock
      end # each ARGV |keg|
    else # --force in effect; remove all versions
      ARGV.racks.each do |rack|
        if f = attempt_from_rack(rack)
          f.unpin rescue nil
          f.uninsinuate if f.uninsinuate_defined?  # Repeat this later, so helper scripts can self‐
                                                   # delete if the rack has gone.
        end
        if rack.directory?
          puts "Uninstalling #{rack.basename}... (#{rack.abv})"
          rack.subdirs.each do |d|
            keg = Keg.new(d)
            keg.unlink
            keg.uninstall  # this also deletes the whole rack when it’s empty
          end
        end
      end
    end # --force?
    f.uninsinuate if f and f.uninsinuate_defined?  # This repetition lets helper scripts self‐
                                                   # delete if the rack has gone.
  rescue MultipleVersionsInstalledError => e
    ofail e
    puts "Use `brew uninstall --force #{e.name}` to remove all versions."
  ensure
    # If we delete Cellar/newname and Cellar/oldname symlink breaks, we have to remove it.
    HOMEBREW_CELLAR.children.each{ |r| r.unlink if r.symlink? and not r.resolved_path_exists? }
  end # uninstall

  def attempt_from_keg(k); Formulary.from_keg(k); rescue FormulaUnavailableError; return nil; end

  def attempt_from_rack(r); Formulary.from_rack(r); rescue FormulaUnavailableError; return nil; end
end # Homebrew
