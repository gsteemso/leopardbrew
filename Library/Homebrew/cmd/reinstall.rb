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

    keg = Keg.new(tab.tabfile.parent)
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
    # delete the old version if both are present and they are not the same
    keg.root.rmtree if f.prefix.exists? and keg.exists? and keg.root != f.prefix
  end # reinstall_formula

  def puree_options(use_opts, formula)
    def whinge_re_unrecognized(flag)
      puts "Ignoring unrecognized option:  #{flag}"
      if flag[-1] == '='
        alt = flag.chop
        puts "did you mean #{alt}?" if formula.option_defined?(alt)
      end
    end # whinge_re_unrecognized

    anti_opts = Options.new
    ARGV.flags_only.each do |flag|
      flag =~ /^--([^=]+=?)(.+)?$/
      o = Option.new($1)
      unrecognized = false
      if formula.option_defined?(o)
        use_opts |= [o]
      else
        case o.flag
        when /^--with-(.+)$/
          if formula.option_defined?(inverse = "without-#{$1}")
            anti_opts |= [Option.new(inverse)]
          else
            unrecognized = true
          end # --with-xxxx?
        when /^--without-(.+)$/
          if formula.option_defined?(inverse = "with-#{$1}")
            anti_opts |= [Option.new(inverse)]
          else
            unrecognized = true
          end # --without-xxxx?
        when '--single-arch'
          anti_opts |= [Option.new('universal')]
        when '--stable'
          anti_opts |= [Option.new('HEAD'), Option.new('devel')]
        when '--devel'
          anti_opts |= [Option.new('HEAD')]
        when '--HEAD'
          anti_opts |= [Option.new('devel')]
        else
          flag =~ /^--un-([^=]+=?)(.+)?$/
          if use_opts.include?($1)
            anti_opts |= [Option.new($1)]
          else
            unrecognized = true
          end # un-option?
        end # case
        whinge_re_unrecognized(o.flag) if unrecognized
      end # option is defined?
    end # each ARGV flag
    use_opts - anti_opts
  end # puree_options
end # Homebrew
