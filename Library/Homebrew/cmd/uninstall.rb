require "keg"
require "formula"
require "migrator"

module Homebrew
  def uninstall
    raise KegUnspecifiedError if ARGV.named.empty?

    unless ARGV.force? # remove active version only
      ARGV.kegs.each do |keg|
        keg.lock do
          puts "Uninstalling #{keg}... (#{keg.abv})"
          keg.unlink
          keg.uninstall  # this also deletes the whole rack, if it’s empty
          rack = keg.rack
          f = Formulary.from_rack(rack)
          f.unpin rescue nil

          if rack.directory?
            f.greatest_installed_keg.optlink
            versions = rack.subdirs.map(&:basename)
            verb = versions.length == 1 ? 'is' : 'are'
            puts "#{keg.name} #{versions.join(", ")} #{verb} still installed."
            puts "Remove them all with `brew uninstall --force #{keg.name}`."
          else
            f.uninsinuate  # call this only after the rack is gone, so any helper scripts can
          end              # delete themselves
        end
      end
    else # --force in effect; remove all versions
      ARGV.named.each do |name|
        rack = Formulary.to_rack(name)
        name = rack.basename
        f = Formulary.from_rack(rack)

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
        f.unpin rescue nil
      end
    end # --force?
  rescue MultipleVersionsInstalledError => e
    ofail e
    puts "Use `brew uninstall --force #{e.name}` to remove all versions."
  ensure
    # If we delete Cellar/newname, then Cellar/oldname symlink
    # can become broken and we have to remove it.
    HOMEBREW_CELLAR.children.each do |rack|
      rack.unlink if rack.symlink? && !rack.resolved_path_exists?
    end
  end # uninstall
end # Homebrew
