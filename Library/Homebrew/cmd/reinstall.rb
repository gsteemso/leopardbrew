require 'formula_installer'

module Homebrew
  def reinstall
    FormulaInstaller.prevent_build_flags unless MacOS.has_apple_developer_tools?

    ARGV.resolved_formulae.each do |f|
      if f.installed?
        reinstall_formula(f)
      else
        opoo <<-_.undent
          The formula #{f.name} could not be reinstalled because it was not installed
          in the first place.  Use “brew install #{f.name}” instead.
        _
      end
    end
  end # reinstall

  def reinstall_formula(f)
    tab = Tab.for_formula(f)
    options = puree_options(tab.used_options, f)

    notice  = "Reinstalling #{f.full_name}"
    notice += " with #{options * ", "}" unless options.empty?
    oh1 notice

    keg = (f.opt_prefix.directory? ? Keg.new(f.opt_prefix.resolved_path) : f.greatest_installed_keg)
    raise NoSuchKegError unless keg
    proper_name = keg.to_s
    keg.unlink if (was_linked = keg.linked?)
    ignore_interrupts { keg.rename "#{keg}.reinstall" }

    fi = FormulaInstaller.new(f)
    fi.options             = options
    fi.build_bottle        = ARGV.build_bottle? || (!f.bottled? && tab.build_bottle?)
    fi.build_from_source   = ARGV.build_from_source?
    fi.force_bottle        = ARGV.force_bottle?
    fi.verbose             = ARGV.verbose?
    fi.debug               = ARGV.debug?
    fi.prelude
    fi.install
    fi.finish
    fi.insinuate
  rescue FormulaInstallationAlreadyAttemptedError
    # next
  rescue Exception
    if keg
      ignore_interrupts { keg.rename proper_name }
      keg.link if was_linked
    end
    raise
  else
    keg.root.rmtree if keg.exists?
  end # reinstall_formula

  def puree_options(opts, formula)
    anti_opts = Options.new
    ARGV.flags_only.each do |flag|
      case flag
      when /^--with-(.+)$/
        if formula.option_defined?(flag)
          opts |= flag
        elsif opts.include?(anti_flag = "--without-#{$1}") or 
          anti_opts |= anti_flag
        else
          whinge_re_unrecognized(flag)
        end # --with-xxxx?
      when /^--without-(.+)$/
        if formula.option_defined?(flag)
          opts |= flag
        elsif opts.include?(anti_flag = "--with-#{$1}")
          anti_opts |= anti_flag
        else
          whinge_re_unrecognized(flag)
        end # --without-xxxx?
      when '--single-arch'
        anti_opts |= '--universal'
      when '--stable'
        anti_opts |= ['--HEAD', '--devel']
      when '--devel'
        anti_opts |= '--HEAD'
      when '--HEAD'
        anti_opts |= '--devel'
      else
        if formula.option_defined?(flag)
          opts |= flag
        else
          whinge_re_unrecognized(flag)
        end # other option?
      end # case
    end # each effective flag
    opts - anti_opts
  end # puree_options

  def whinge_re_unrecognized(flag)
    puts "Ignoring unrecognized option:  #{flag}"
  end
end # Homebrew
