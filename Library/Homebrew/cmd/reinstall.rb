#:
#:  Usage:  brew reinstall [/formula options/] /installed formula/ [...]
#:
#:Reïnstall each listed /installed formula/, with the same options each used
#:before.  Further options may be added, but will apply to every formula.
#:
#:If multiple current specifications are installed (in the extreme case, all
#:three of stable, devel, and HEAD), do clarify which one to reïnstall using or
#:omitting the usual options and/or the special option “--stable”.  If you name
#:a specification that ISN’T installed, the others will be removed upon success.
#:
#:Active options may be removed by specifying their opposite.  A formula brewed
#:--with-A may be reïnstalled --without-A to cancel it, and one --without-B may
#:be reïnstalled --with-B.  (“--universal”, having no obvious opposite, may be
#:cancelled by specifying “--single-arch”.)
#:

require 'formula_installer'

module Homebrew
  def reinstall
    FormulaInstaller.prevent_build_flags unless MacOS.has_apple_developer_tools?

    raise 'Specify “--HEAD” in uppercase to build from the latest source code.' if ARGV.include? '--head'

    ARGV.resolved_formulae.each do |f|
      if f.installed?
        reinstall_formula(f)
      else
        opoo <<-_.undent
          The formula #{f.name} could not be reinstalled because no current version of it
          is installed in the first place.  Use “brew install #{f.name}” instead.
        _
      end
    end
  end # reinstall

  def reinstall_formula(f)
    existing_prefixes = f.installed_current_prefixes.values
    ohai 'installed current prefixes:', existing_prefixes * ' ' if DEBUG
    named_spec = (ARGV.build_head? ? :head :
                   (ARGV.build_devel? ? :devel :
                     (ARGV.include?('--stable') ? :stable :
                       nil) ) )
    oh1 "Named spec = #{named_spec or '[nil]'}" if DEBUG
    f.set_active_spec named_spec if named_spec  # otherwise use the default
    tab = Tab.for_formula(f)
    options = tab.used_options
    oh1 "Original spec = #{tab[:source][:spec] or '[nil]'}" if DEBUG
    case tab[:source][:spec]
      when :head then options += Option.new('HEAD')
      when :devel then options += Option.new('devel')
    end
    options = blenderize_options(options, f)
    new_spec = (options.include?('HEAD') ? :head : (options.include?('devel') ? :devel : :stable) )
    oh1 "New spec = #{new_spec or '[nil]'}" if DEBUG
    f.set_active_spec new_spec
    keep_other_current_kegs = existing_prefixes.include?(f.prefix)
    oh1 "Replace other current kegs?  #{keep_other_current_kegs ? 'NO' : 'YES'}" if DEBUG
    notice  = "Reinstalling #{f.full_name}"
    notice += " with #{options * ', '}" unless options.empty?
    oh1 notice

    keg = Keg.new(tab.tabfile.parent)
    raise NoSuchKegError unless keg
    proper_name = keg.to_s
    keg.unlink if (was_linked = keg.linked?)
    ignore_interrupts { keg.rename "#{keg}.reinstall" }

    fi = FormulaInstaller.new(f)
    fi.options             = options
    fi.ignore_deps         = ARGV.ignore_deps?
    fi.only_deps           = ARGV.only_deps?
    fi.build_bottle        = ARGV.build_bottle? or (!f.bottled? and tab.build_bottle?)
    fi.build_from_source   = ARGV.build_from_source?
    fi.force_bottle        = ARGV.force_bottle?
    fi.interactive         = ARGV.interactive?
    fi.git                 = ARGV.git?
    fi.verbose             = ARGV.verbose?
    fi.quieter             = ARGV.quieter?
    fi.debug               = ARGV.debug?
    fi.prelude
    fi.install
    fi.finish
    fi.insinuate

  rescue FormulaInstallationAlreadyAttemptedError
    # next
  rescue Exception
    # leave no trace of the failed installation
    if f.prefix.exists?
      oh1 "Cleaning up failed #{f.prefix}" if DEBUG
      f.prefix.rmtree
    end
    if keg
      ignore_interrupts { keg.rename proper_name }
      keg.link if was_linked
    end
    raise
  else
    if f.prefix.exists?
      # delete the old version if both are present and they aren’t the same
      if keg.exists? and keg.root != f.prefix
        oh1 "Deleting superfluous #{keg}" if DEBUG
        keg.root.rmtree
      end
      # also delete other current specifications if the one we just installed wasn’t among them
      unless keep_other_current_kegs
        existing_prefixes.each do |p|
          oh1 "Deleting replaced #{p}" if DEBUG
          p.rmtree
        end
      end
    end
  end # reinstall_formula

  def blenderize_options(use_opts, formula)
    def whinge_re_unrecognized(flag)
      puts "Ignoring unrecognized option:  #{flag}"
      if flag[-1] == '='
        alt = flag.chop
        puts "did you mean #{alt}?" if formula.option_defined?(alt)
      end
    end # whinge_re_unrecognized

    anti_opts = Options.new
    ARGV.effective_formula_flags.each do |flag|
      flag =~ /^--([^=]+=?)(.+)?$/
      o = Option.new($1)
      unrecognized = false
      if formula.option_defined?(o)
        use_opts += [o]
      else
        case o.flag
        when /^--with-(.+)$/
          if formula.option_defined?(inverse = "without-#{$1}")
            anti_opts += [Option.new(inverse)]
          else
            unrecognized = true
          end # --with-xxxx?
        when /^--without-(.+)$/
          if formula.option_defined?(inverse = "with-#{$1}")
            anti_opts += [Option.new(inverse)]
          else
            unrecognized = true
          end # --without-xxxx?
        when '--single-arch'
          anti_opts += [Option.new('universal')]
        when '--stable'
          anti_opts += [Option.new('HEAD'), Option.new('devel')]
        when '--devel'
          use_opts += [o]
          anti_opts += [Option.new('HEAD')]
        when '--HEAD'
          use_opts += [o]
          anti_opts += [Option.new('devel')]
        else
          flag =~ /^--un-([^=]+=?)(.+)?$/
          if use_opts.include?($1)
            anti_opts += [Option.new($1)]
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
