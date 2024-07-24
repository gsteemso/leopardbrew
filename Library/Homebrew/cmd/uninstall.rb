require "keg"
require "formula"
require "migrator"

module Homebrew
  def uninstall
    raise KegUnspecifiedError if ARGV.named.empty?

    unless ARGV.force?
      ARGV.kegs.each do |keg|
        keg.lock do
          puts "Uninstalling #{keg}... (#{keg.abv})"
          keg.unlink
          keg.uninstall  # this also deletes the whole rack, if it’s empty
          rack = keg.rack
          rm_pin rack

          if rack.directory?
            versions = rack.subdirs.map(&:basename)
            verb = versions.length == 1 ? 'is' : 'are'
            puts "#{keg.name} #{versions.join(", ")} #{verb} still installed."
            puts "Remove them all with `brew uninstall --force #{keg.name}`."
          else
            Formulary.from_rack(rack).uninsinuate  # call this only after the rack is gone, so any
          end                                      # helper scripts can delete themselves
        end
      end
    else
      ARGV.named.each do |name|
        rack = Formulary.to_rack(name)
        name = rack.basename

        if rack.directory?
          puts "Uninstalling #{name}... (#{rack.abv})"
          rack.subdirs.each do |d|
            keg = Keg.new(d)
            keg.unlink
            keg.uninstall  # this also deletes the whole rack when it’s empty
          end
        end
        Formulary.from_rack(rack).uninsinuate  # call this only after the rack is gone, so any
                                               # helper scripts can delete themselves
        rm_pin rack
      end
    end
  rescue MultipleVersionsInstalledError => e
    ofail e
    puts "Use `brew uninstall --force #{e.name}` to remove all versions."
  ensure
    # If we delete Cellar/newname, then Cellar/oldname symlink
    # can become broken and we have to remove it.
    HOMEBREW_CELLAR.children.each do |rack|
      rack.unlink if rack.symlink? && !rack.resolved_path_exists?
    end
  end

  def rm_pin(rack)
    Formulary.from_rack(rack).unpin rescue nil
  end
end
