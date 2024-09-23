require "formula"
require "keg"
require "tab"

module Homebrew
  def switch
    if ARGV.named.length != 2
      onoe "Usage: brew switch <name> <version>"
      exit 1
    end

    name = ARGV.shift
    version = ARGV.shift

    rack = Formulary.to_rack(name)

    unless rack.directory?
      onoe "#{name} was not found in the Cellar."
      exit 2
    end

    # Does the target version exist?
    versions = rack.subdirs.map { |sd| sd.basename.to_s }
    possibles = versions.select { |v| v =~ /^#{version}(_\d+)?$/ }
    if possibles == []
      onoe "Version “#{version}” of #{name} is not present in the Cellar."
      puts "Versions available:  #{versions * ', '}"
      exit 3
    end
    full_version = possibles.sort.reverse.first
    chosen_prefix = rack/full_version

    unless f = Formula.from_installed_prefix(chosen_prefix)
      onoe "Version “#{full_version}” of #{name} is not installed properly."
      exit 4
    end

    oh1 "Switching to revision #{full_version} of #{name}." if full_version != version

    # Unlink all existing versions
    rack.subdirs.each do |v|
      keg = Keg.new(v)
      puts "Cleaning #{keg}"
      keg.unlink
    end

    keg = Keg.new(chosen_prefix)

    # Link new version, if not keg-only
    if f.keg_only?
      keg.optlink
      puts "opt/ link created for #{keg}"
    else
      puts "#{keg.link} links created for #{keg}"
    end
  end
end
