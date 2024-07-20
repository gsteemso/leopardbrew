require 'formula_installer'

module Homebrew
  def reinstall
    FormulaInstaller.prevent_build_flags unless MacOS.has_apple_developer_tools?

    ARGV.resolved_formulae.each { |f| reinstall_formula(f) }
  end

  def reinstall_formula(f)
    tab = Tab.for_formula(f)
    options = puree_options(tab.used_options, f)

    notice  = "Reinstalling #{f.full_name}"
    notice += " with #{options * ", "}" unless options.empty?
    oh1 notice

    if f.opt_prefix.directory?
      keg = Keg.new(f.opt_prefix.resolved_path)
      backup keg
    end

    fi = FormulaInstaller.new(f)
    fi.options             = options
    fi.build_bottle        = ARGV.build_bottle? || (!f.bottled? && tab.build_bottle?)
    fi.build_from_source   = ARGV.build_from_source?
    fi.force_bottle        = ARGV.force_bottle?
    fi.verbose             = ARGV.verbose?
    fi.debug               = ARGV.debug?
    fi.prelude
    fi.install
    fi.finish  # this calls Formula#insinuate for us
  rescue FormulaInstallationAlreadyAttemptedError
    # next
  rescue Exception
    ignore_interrupts { restore_backup(keg, f) }
    raise
  else
    backup_path(keg).rmtree if backup_path(keg).exist?
  end

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
      when /^--single-arch$/
        anti_opts |= '--universal'
      when /^--stable$/
        anti_opts |= ['--HEAD', '--devel']
      when /^--devel$/
        anti_opts |= '--HEAD'
      else
        if formula.option_defined?(flag)
          opts |= flag
        else
          whinge_re_unrecognized(flag)
        end # other option?
      end # case
    end # each effective flag
    opts - anti_opts
  end

  def whinge_re_unrecognized(flag)
    puts "Ignoring unrecognized option:  #{flag}"
  end

  def backup(keg)
    keg.unlink  # this calls Formula#uninsinuate for us
    keg.rename backup_path(keg)
    keg.optlink # this allows reïnstalling things that the build system depends upon
  end

  def restore_backup(keg, formula)
    path = backup_path(keg)
    if path.directory?
      path.rename keg
      keg.optlink  # restore original optlink
      keg.link unless formula.keg_only?
      formula.insinuate
    end
  end

  def backup_path(path)
    Pathname.new "#{path}.reinstall"
  end
end
