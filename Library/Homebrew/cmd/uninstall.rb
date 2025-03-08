require "keg"
require "formula"
require "migrator"

module Homebrew
  def uninstall
    raise KegUnspecifiedError if ARGV.named.empty?
    f = nil
    unless ARGV.force? # remove active version only
      ARGV.kegs.each do |keg|
        was_linked = keg.linked?
        keg.lock do
          puts "Uninstalling #{keg}... (#{keg.abv})"
          keg.unlink
          keg.uninstall  # this also deletes the whole rack, if it’s empty
          if f = attempt_from_keg(keg) then f.unpin rescue nil; end
          rack = keg.rack
          if rack.directory?
            if (dirs = rack.subdirs) != []
              # hook up the next keg in line
              next_keg = dirs.map { |d| Keg.new(d) }.max_by(&:version)
              next_keg.optlink
              next_keg.link if was_linked
              if f = attempt_from_keg(next_keg) then f.insinuate; end
              # report on whatever’s still installed
              versions = dirs.map(&:basename)
              verb = versions.length == 1 ? 'is' : 'are'
              puts "#{keg.name} #{versions.join(", ")} #{verb} still installed."
              puts "Remove them all with `brew uninstall --force #{keg.name}`."
            else # rack still exists even though empty of subdirectories – fix that:
              rack.rm_rf
            end
          end # rack is a directory
        end # keg lock
      end # each ARGV |keg|
    else # --force in effect; remove all versions
      ARGV.named.each do |name|
        if name =~ VERSIONED_NAME_REGEX then name = $1; end  # nuking ’em all; ignore given version
        rack = Formulary.to_rack(name)
        name = rack.basename
        if f = attempt_from_rack(rack) then f.unpin rescue nil; end
        if rack.directory?
          puts "Uninstalling #{name}... (#{rack.abv})"
          rack.subdirs.each do |d|
            keg = Keg.new(d)
            keg.unlink
            keg.uninstall  # this also deletes the whole rack when it’s empty
          end
        end
      end
    end # --force?
  rescue MultipleVersionsInstalledError => e
    ofail e
    puts "Use `brew uninstall --force #{e.name}` to remove all versions."
  ensure
    # If we delete Cellar/newname, then Cellar/oldname symlink
    # can become broken and we have to remove it.
    HOMEBREW_CELLAR.children.each do |rack|
      rack.unlink if rack.symlink? and not rack.resolved_path_exists?
    end
    f.uninsinuate if f  # Do only after the rack is gone, so helper scripts can delete themselves.
  end # uninstall

  def attempt_from_keg(k)
    Formulary.from_keg(k)
  rescue FormulaUnavailableError
    return nil
  end

  def attempt_from_rack(r)
    Formulary.from_rack(r)
  rescue FormulaUnavailableError
    return nil
  end
end # Homebrew
