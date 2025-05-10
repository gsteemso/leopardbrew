require "cmd/install"
require "cmd/outdated"
require 'cmd/reinstall'

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
          installed_version = f.greatest_installed_keg.version
          onoe "#{f.full_name} #{installed_version} is already installed" \
                                               if f.version == installed_version
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

    named_spec = (ARGV.build_head? ? :head :
                   (ARGV.build_devel? ? :devel :
                     (ARGV.include?('--stable') ? :stable :
                       nil) ) )
    puts "Named spec = #{named_spec or '[none]'}" if DEBUG

    outdated.each { |f| upgrade_formula(f, named_spec) }
  end # upgrade

  def upgrade_pinned?
    not ARGV.named.empty?
  end

  def upgrade_formula(f, s)
    case s
      when nil, :stable
        if f.stable.nil?
          if f.devel.nil?
            raise "#{f.full_name} is a head‐only formula, please specify --HEAD"
          elsif f.head.nil?
            raise "#{f.full_name} is a development‐only formula, please specify --devel"
          else
            raise "#{f.full_name} has no stable download, please choose --devel or --HEAD"
          end
        end
      when :head then raise "No head is defined for #{f.full_name}" if f.head.nil?
      when :devel then raise "No devel block is defined for #{f.full_name}" if f.devel.nil?
    end
    f.set_active_spec s if s  # otherwise use the default
    previously_linked = nil
    if f.linked_keg.directory?
      previously_linked = Keg.new(f.linked_keg.resolved_path)
      previously_linked.unlink
    end
    tab = Tab.for_keg(f.greatest_installed_keg)
    options = tab.used_options
    puts "Original spec = #{tab.spec.to_s or '[none]'}" if DEBUG
    case tab.spec
      when :head then options |= Option.new('HEAD')
      when :devel then options |= Option.new('devel')
    end
    options = Homebrew.blenderize_options(options, f)
    new_spec = (options.include?('HEAD') ? :head : (options.include?('devel') ? :devel : :stable) )
    puts "New spec = #{new_spec}" if DEBUG
    f.set_active_spec new_spec # now install to this spec; we don’t care about the Tab any more

    notice  = "Upgrading #{f.full_name}"
    notice += " with #{options * ', '}" unless options.empty?
    oh1 notice

    fi = FormulaInstaller.new(f)
    fi.options             = options
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
  else
    fi.finish  # this links the new keg

    # If the formula was pinned and we were force-upgrading it, unpin and
    # pin it again to get a symlink pointing to the correct keg.
    if f.pinned? then f.unpin; f.pin; end

    begin
      old_stdout = $stdout
      $stdout.reopen('/dev/null')  # Uninsinuation must, if followed immediately by insinuation, be
      f.uninsinuate rescue nil     # silent so as to not emit conflicting messages.
    ensure
      $stdout.reopen(old_stdout)
    end
    f.insinuate
  ensure # Restore the previous installation state if the build failed.
    unless f.installed?
      if f.prefix.exists?
        oh1 "Cleaning up the failed installation #{f.prefix}" if DEBUG
        ignore_interrupts { f.prefix.rmtree; f.rack.rmdir_if_possible }
      end
      ignore_interrupts { previously_linked.link } if previously_linked
    end
  end # upgrade_formula
end # Homebrew
