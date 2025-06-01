#:  Usage:  brew outdated [ [/--HEAD/ | /--devel/] /installed formula/ [...] ]
#:
#:Determine which, if any, of the named /installed formulæ/ are out of date
#:(i.e., would have newer versions if brewed today).
#:
#:If no individual formulæ are named, all installed formulæ are examined.
#:
#:Formulæ may be tagged “--HEAD” or “--devel” to check those versions – though
#:specifying “--HEAD” will generally provide an incorrect result.  (Whether old
#:or recent, a formula installed as --HEAD will always look up‐to‐date, as its
#:version is always “HEAD”.  This is unaffected by whether the upstream
#:repository has in fact been updated since the local version was installed).

require 'formula'
require 'keg'
require 'migrator'

module Homebrew
  def outdated
    formulae = ARGV.resolved_formulae.any? ? ARGV.resolved_formulae : Formula.installed
    if ARGV.json == 'v1'
      outdated = print_outdated_json(formulae)
    else
      outdated = print_outdated(formulae)
    end
    Homebrew.failed = ARGV.resolved_formulae.any? && outdated.any?
  end # outdated

  def outdated_brews(formulae)
    formulae.map do |f|
      all_versions = []
      older_or_same_tap_versions = []
      if f.oldname and not f.rack.exists? and (dir = HOMEBREW_CELLAR/f.oldname).exists?
        if f.tap == Tab.for_keg(dir.subdirs.first).tap
          raise Migrator::MigrationNeededError.new(f)
        end
      end
      f.rack.subdirs.each do |keg_dir|
        keg = Keg.new keg_dir
        version = keg.version
        all_versions << version
        older_version = f.pkg_version > version
        tap = Tab.for_keg(keg).tap
        if tap.nil? or f.tap == tap or older_version
          older_or_same_tap_versions << version
        end
      end
      if older_or_same_tap_versions.all? { |version| f.pkg_version > version }
        yield f, all_versions if block_given?
        f
      end
    end.compact
  end # outdated_brews

  def print_outdated(formulae)
    verbose = ($stdout.tty? or VERBOSE) and not QUIETER
    outdated_brews(formulae) do |f, versions|
      if verbose
        puts "#{f.full_name} (#{versions * ', '} < #{f.pkg_version})"
      else
        puts f.full_name
      end
    end
  end # print_outdated

  def print_outdated_json(formulae)
    json = []
    outdated = outdated_brews(formulae) do |f, versions|
      json << { :name => f.full_name,
                :installed_versions => versions.collect(&:to_s),
                :current_version => f.pkg_version.to_s }
    end
    puts Utils::JSON.dump(json)
    outdated
  end # print_outdated_json
end # Homebrew
