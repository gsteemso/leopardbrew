require "cmd/install"
require "cmd/outdated"

module Homebrew
  def upgrade
    FormulaInstaller.prevent_build_flags unless MacOS.has_apple_developer_tools?

    Homebrew.perform_preinstall_checks

    if ARGV.named.empty?
      outdated = Homebrew.outdated_brews(Formula.installed)
      exit 0 if outdated.empty?
    elsif ARGV.named.any?
      outdated = Homebrew.outdated_brews(ARGV.resolved_formulae)

      (ARGV.resolved_formulae - outdated).each do |f|
        if f.rack.directory?
          version = f.greatest_installed_keg.version
          onoe "#{f.full_name} #{version} is already installed"
        else
          onoe "#{f.full_name} is not installed"
        end
      end
      exit 1 if outdated.empty?
    end

    unless upgrade_pinned?
      pinned = outdated.select(&:pinned?)
      outdated -= pinned
    end

    if outdated.empty?
      oh1 "No packages to upgrade"
    else
      ohai "Upgrading #{outdated.length} outdated package#{plural(outdated.length)}, with result:", \
                                        outdated.map { |f| "#{f.full_name} #{f.pkg_version}" } * ", "
    end

    ohai "Not upgrading #{pinned.length} pinned package#{plural(pinned.length)}:", \
                        pinned.map { |f| "#{f.full_name} #{f.pkg_version}" } * ", " \
                                                            unless upgrade_pinned? or pinned.empty?

    outdated.each { |f| upgrade_formula(f) }
  end # upgrade

  def upgrade_pinned?
    not ARGV.named.empty?
  end

  def upgrade_formula(f)
    oh1 "Upgrading #{f.full_name}"

    # this correctly unlinks things no matter what version is linked
    if f.linked_keg.directory?
      previously_linked = Keg.new(f.linked_keg.resolved_path)
      previously_linked.unlink
    end

    tab = Tab.for_formula(f)
    fi = FormulaInstaller.new(f)
    fi.options             = tab.used_options
    fi.ignore_deps         = ARGV.ignore_deps?
    fi.only_deps           = ARGV.only_deps?
    fi.build_from_source   = ARGV.build_from_source?
    fi.build_bottle        = ARGV.build_bottle?
    fi.force_bottle        = ARGV.force_bottle?
    fi.interactive         = ARGV.interactive? or ARGV.git?
    fi.git                 = ARGV.git?
    fi.verbose             = VERBOSE or QUIETER
    fi.quieter             = QUIETER
    fi.debug               = DEBUG
    fi.prelude
    fi.install
  rescue FormulaInstallationAlreadyAttemptedError
    # next
  rescue CannotInstallFormulaError => e
    ofail e
  rescue BuildError => e
    ofail e.dump
  rescue DownloadError => e
    ofail e
  ensure
    # Restore the previous installation state if the build failed.
    unless f.installed?
      if f.prefix.exists?
        oh1 "Cleaning up failed #{f.prefix}" if DEBUG
        ignore_interrupts { f.prefix.rmtree }
      end
      ignore_interrupts { previously_linked.link } if previously_linked
    end rescue nil
  else
    fi.finish  # this links the new keg

    # If the formula was pinned and we were force-upgrading it, unpin and
    # pin it again to get a symlink pointing to the correct keg.
    if f.pinned? then f.unpin; f.pin; end

    fi.insinuate
  end # upgrade_formula
end # Homebrew
