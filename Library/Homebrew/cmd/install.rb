#:  Usage:  brew install [/options/] /formula/ [...]
#:
#:Install each listed /formula/, applying the /options/ to each one.
#:
#:  --build-bottle   - Prepare a bottled version of the software.  Specify what
#:                     platform to build it for with “--bottle-arch=____”.
#:  --build-from-source - Build from source code, even if a bottle is available.
#:  --cc=/compiler/  - Use /compiler/ to build the software.
#:  --debug (-d)     - See messages for debugging the software installation.
#:  --devel, --HEAD  - Install the development version or the source repository,
#:                     if available.  These are mutually exclusive.
#:  --force (-f)     - Install the formula even if it might cause problems.
#:  --force-bottle   - Use the bottled version.  Overrides --build-from-source.
#:  --git (-g)       - Install by making a Git repository.  Implies -i.
#:  --ignore-dependencies - Assume that the software’s dependencies are present.
#:  --interactive (-i) - Install “by hand” using the command line.  Any patches
#:                       the formula defines will have already been applied.
#:  --no-enhancements - Install dependencies, but do not apply enhancements.
#:  --only-dependencies - Install its dependencies, but not the formula itself.
#:  --quieter (-q)   - Don’t be verbose when brewing dependencies.  Implies -v.
#:  --verbose (-v)   - See lots of progress messages as the software builds.

require 'blacklist'
require 'cmd/doctor'
require 'cmd/search'
require 'cmd/tap'
require 'cpu'
require 'formula/installer'

module Homebrew
  def install
    raise FormulaUnspecifiedError if ARGV.named.empty?
    raise 'Specify “--HEAD” in uppercase to build from the latest source code.' if ARGV.include? '--head'
    raise '--ignore-dependencies and --only-dependencies are mutually exclusive.' \
                                                           if ARGV.ignore_deps? and ARGV.only_deps?
    # if the user's flags will prevent bottle only-installations when no
    # developer tools are available, we need to stop them early on
    FormulaInstaller.prevent_build_flags unless MacOS.has_apple_developer_tools?

    ARGV.named.each do |name|
      if !File.exists?(name) and (name !~ HOMEBREW_CORE_FORMULA_REGEX) \
                and (name =~ HOMEBREW_TAP_FORMULA_REGEX or name =~ HOMEBREW_CASK_TAP_FORMULA_REGEX)
        install_tap $1, $2
      end
    end unless ARGV.force?

    begin
      formulae = []

      if ARGV.casks.any?
        brew_cask = Formulary.factory('brew-cask')
        install_formula(brew_cask) unless brew_cask.installed?
        args = []
        args << '--force' if ARGV.force?
        args << '--debug' if DEBUG
        args << '--verbose' if VERBOSE

        ARGV.casks.each do |c|
          cmd = 'brew', 'cask', 'install', c, *args
          ohai cmd.join ' '
          system(*cmd)
        end
      end

      ARGV.formulae.each do |f|
        requested_spec = (ARGV.build_head? ? :head : (ARGV.build_devel? ? :devel : :stable))
        case requested_spec
          when :stable
            if f.stable.nil?
              if f.devel.nil?
                raise UsageError, "#{f.full_name} is a head‐only formula, please specify --HEAD"
              elsif f.head.nil?
                raise UsageError, "#{f.full_name} is a development‐only formula, please specify --devel"
              else
                raise UsageError, "#{f.full_name} has no stable download, please choose --devel or --HEAD"
              end
            end
          when :head then raise UsageError, "No head is defined for #{f.full_name}" if f.head.nil?
          when :devel then raise UsageError, "No devel block is defined for #{f.full_name}" if f.devel.nil?
        end

        if f.installed?(requested_spec)
          msg = "#{f.full_name} #{f.send(requested_spec).version} is already installed"
          msg << ', it’s just not linked' unless f.keg_only? or (f.linked_keg.symlink? and
                                  f.linked_keg.resolved_real_path == f.spec_prefix(requested_spec))
          msg << '.'
          opoo msg
        elsif f.old_version_installed?
          opoo <<-_.undent
              An outdated version of #{f.full_name} is already installed.  Use
                  brew upgrade #{f.full_name}
              instead.
            _
        elsif f.oldname_installed? and not ARGV.force?
          # Check if the formula we try to install is the same as installed
          # but not migrated one. If --force passed then install anyway.
          opoo "#{f.oldname} is already installed, it’s just not migrated.",
            "You can migrate this formula with `brew migrate #{f}`,\n",
            "or you can force‐install it with `brew install #{f} --force`."
        else
          formulae << f
        end
      end # each ARGV formula |f|

      perform_preinstall_checks

      formulae.each do |f|
        notice  = "Installing #{f.full_name}"
        notice += " with #{f.build.used_options * ', '}" unless f.build.used_options.empty?
        oh1 notice

        install_formula(f)
      end
    rescue FormulaUnavailableError => e
      if (blacklist = blacklisted?(e.name))
        ofail "#{e.message}\n#{blacklist}"
      else
        ofail e.message
        query = query_regexp(e.name)
        ohai 'Searching formulae...'
        puts_columns(search_formulae(query))
        ohai 'Searching taps...'
        puts_columns(search_taps(query))

        # If they haven't updated in a while, that might explain the error
        master = HOMEBREW_REPOSITORY/'.git/refs/heads/master'
        if master.exists? and (Time.now.to_i - File.mtime(master).to_i) > HOMEBREW_OUTDATED_LIMIT
          ohai 'You haven’t updated Leopardbrew in a while.', <<-EOS.undent
            A formula for #{e.name} might have been added recently.
            Run “brew update” to get the latest Leopardbrew updates!
          EOS
        end # outdated?
      end # not blacklisted
    rescue UsageError => e
      ofail e.message
    end # rescue blocks
  end # install

  def check_writable_install_location
    raise "Cannot write to #{HOMEBREW_CELLAR}" unless HOMEBREW_CELLAR.writable_real?
    raise "Cannot write to #{HOMEBREW_PREFIX}" unless HOMEBREW_PREFIX.writable_real?
  end

  def check_xcode
    checks = Checks.new
    %w[
      check_for_unsupported_osx
      check_for_bad_install_name_tool
      check_for_installed_developer_tools
      check_xcode_license_approved
      check_for_osx_gcc_installer
    ].each do |check|
      out = checks.send(check)
      opoo out unless out.nil?
    end
  end # check_xcode

  def check_macports
    opoo 'It appears you have MacPorts or Fink installed.',
      <<-_.undent unless MacOS.macports_or_fink.empty?
        Software installed with other package managers causes known problems for
        ’brewing. If a formula fails to build, uninstall MacPorts/Fink and try again.
      _
  end # check_macports

  def check_cellar
    HOMEBREW_CELLAR.mkdir_p unless HOMEBREW_CELLAR.exists?
  rescue
    raise <<-EOS.undent
      Could not create #{HOMEBREW_CELLAR}
      Check you have permission to write to #{HOMEBREW_CELLAR.parent}
    EOS
  end # check_cellar

  def perform_preinstall_checks
    check_writable_install_location
    check_xcode if MacOS.has_apple_developer_tools?
    check_cellar
  end

  def remove_failed_install(f)
    # Leave no trace of the failed installation.
    if f.prefix.exists?
      oh1 "Cleaning up the failed installation #{f.prefix}" if DEBUG
      ignore_interrupts { f.prefix.rmtree; f.rack.rmdir_if_possible }
    end
  end # remove_failed_install

  def install_formula(f)
    f.print_tap_action

    fi = FormulaInstaller.new(f)
    fi.options             = f.build.used_options
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
    remove_failed_install(f)
    ofail e.message
  rescue BuildError
    remove_failed_install(f)
    check_macports
    raise
  rescue Exception => e
    puts e.inspect if DEBUG
    remove_failed_install(f)
    raise
  else
    fi.finish
    f.insinuate
  end # install_formula
end # Homebrew
