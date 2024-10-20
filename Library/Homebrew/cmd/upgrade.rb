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
  end

  def upgrade_pinned?
    not ARGV.named.empty?
  end

  def upgrade_formula(f)
    outdated_keg = Keg.new(f.linked_keg.resolved_path) if f.linked_keg.directory?
    oh1 "Upgrading #{f.full_name}"
    # First we unlink the currently active keg for this formula.  Otherwise it is
    # possible for the existing build to interfere with the build we are about to
    # do!  Seriously, it happens!
    outdated_keg.unlink if outdated_keg

    tab = Tab.for_formula(f)
    fi = FormulaInstaller.new(f)
    fi.options             = tab.used_options
    fi.ignore_deps         = ARGV.ignore_deps?
    fi.only_deps           = ARGV.only_deps?
    fi.build_from_source   = ARGV.build_from_source?
    fi.build_bottle        = ARGV.build_bottle? || (!f.bottled? && tab.build_bottle?)
    fi.force_bottle        = ARGV.force_bottle?
    fi.interactive         = ARGV.interactive?
    fi.git                 = ARGV.git?
    fi.verbose             = VERBOSE
    fi.quieter             = ARGV.quieter?
    fi.debug               = DEBUG
    fi.prelude
    fi.install
    fi.finish

    # If the formula was pinned and we were force-upgrading it, unpin and
    # pin it again to get a symlink pointing to the correct keg.
    if f.pinned? then f.unpin; f.pin; end

    fi.insinuate
  rescue FormulaInstallationAlreadyAttemptedError
    # We already attempted to upgrade f as part of the dependency tree of
    # another formula. In that case, don't generate an error, just move on.
  rescue CannotInstallFormulaError => e
    ofail e
  rescue BuildError => e
    e.dump
    puts
    Homebrew.failed = true
  rescue DownloadError => e
    ofail e
  ensure
    # Restore the previous installation state if the build failed.
    outdated_keg.link if outdated_keg && !f.installed? rescue nil
  end
end
