#:  Usage:  brew outdated [ [--devel] <installed formula> [...] ]
#:
#:Determine which, if any, of the named installed formulæ are out of date – i.e.,
#:would have newer versions if brewed today.
#:
#:If no specific installed formula is named, all installed formulæ are examined.
#:
#:If “--devel” is specified, the target formulæ are examined to see whether they
#:name a development version.  For those which do, `brew outdated` uses that for
#:testing outdatedness instead of the stable release’s version.  No similar test
#:yet exists for HEAD formulæ; it would involve mucking about with remote source-
#:code repositories.

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
      versions = []
      if f.oldname and not f.rack.exists? and (dir = HOMEBREW_CELLAR/f.oldname).exists?
        if f.tap == Tab.for_keg(dir.subdirs.first).tap
          raise Migrator::MigrationNeededError.new(f)
        end
      end
      if ARGV.build_devel? and f.devel
        check_version = PkgVersion.new(f.devel.version, f.revision)
        false_positive_version = f.pkg_version
      else
        check_version = f.pkg_version
        false_positive_version = nil
      end
      f.rack.subdirs.each do |keg_dir|
        version = Keg.new(keg_dir).version
        if version != false_positive_version then versions << version; end
      end
      versions = versions.compact
      if versions and not versions.empty? and versions.all?{ |version| version < check_version }
        yield f, versions, check_version if block_given?
        f
      end
    end.compact
  end # outdated_brews

  def print_outdated(formulae)
    verbose = ($stdout.tty? or VERBOSE) and not QUIETER
    outdated_brews(formulae) do |f, versions, check_version|
      if verbose
        puts "#{f.full_name} (#{versions * ', '} < #{check_version}#{' [devel.]' if ARGV.build_devel? and f.devel})"
      else
        puts f.full_name
      end
    end
  end # print_outdated

  def print_outdated_json(formulae)
    json = []
    outdated = outdated_brews(formulae) do |f, versions, check_version|
      json << { :name => f.full_name,
                :installed_versions => versions.collect(&:to_s),
                :current_version => "#{check_version}#{' (devel.)' if ARGV.build_devel? and f.devel}" }
    end
    puts Utils::JSON.dump(json)
    outdated
  end # print_outdated_json
end # Homebrew
