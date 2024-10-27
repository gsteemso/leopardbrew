#:
#:  Usage:  brew reinstall [/formula options/] /installed formula/ [...]
#:
#:Reïnstall each listed /installed formula/, using the same options each used
#:before.  Further options may be added, but will apply to every given formula.
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
    raise FormulaUnspecifiedError if ARGV.named.empty?
    raise 'Specify “--HEAD” in uppercase to build from the latest source code.' if ARGV.include? '--head'
    raise '--ignore-dependencies and --only-dependencies are mutually exclusive.' \
                                                           if ARGV.ignore_deps? and ARGV.only_deps?
    FormulaInstaller.prevent_build_flags unless MacOS.has_apple_developer_tools?

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
    puts 'installed current prefixes:', existing_prefixes * ' ' if DEBUG
    named_spec = (ARGV.build_head? ? :head :
                   (ARGV.build_devel? ? :devel :
                     (ARGV.include?('--stable') ? :stable :
                       nil) ) )
    puts "Named spec = #{named_spec or '[none]'}" if DEBUG
    case named_spec
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
    f.set_active_spec named_spec if named_spec  # otherwise use the default
    tab = Tab.for_formula(f) # this gets the tab for the correct installed keg
    options = tab.used_options
    puts "Original spec = #{tab[:source][:spec] or '[none]'}" if DEBUG
    case tab[:source][:spec]
      when :head then options += Option.new('HEAD')
      when :devel then options += Option.new('devel')
    end
    options = blenderize_options(options, f)
    new_spec = (options.include?('HEAD') ? :head : (options.include?('devel') ? :devel : :stable) )
    puts "New spec = #{new_spec}" if DEBUG
    f.set_active_spec new_spec # now install to this spec; we don’t care about the Tab any more
    keep_other_current_kegs = existing_prefixes.include?(f.prefix)
    puts "Remove other current kegs?  #{keep_other_current_kegs ? 'NO' : 'YES'}" if DEBUG

    notice  = "Reinstalling #{f.full_name}"
    notice += " with #{options * ', '}" unless options.empty?
    oh1 notice

    # this correctly unlinks things no matter what version is linked
    if f.linked_keg.directory?
      previously_linked = Keg.new(f.linked_keg.resolved_path)
      previously_linked.unlink
    end
    ignore_interrupts { (previously_installed = Keg.new tab.tabfile.parent).rename }

    fi = FormulaInstaller.new(f)
    fi.options             = options
    fi.ignore_deps         = ARGV.ignore_deps?
    fi.only_deps           = ARGV.only_deps?
    fi.build_from_source   = ARGV.build_from_source?
    fi.build_bottle        = ARGV.build_bottle? or (!f.bottled? and tab.build_bottle?)
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
  rescue Exception
    # leave no trace of the failed installation
    if f.prefix.exists?
      oh1 "Cleaning up failed #{f.prefix}" if DEBUG
      ignore_interrupts { f.prefix.rmtree }
    end
    ignore_interrupts { previously_installed.rename } if previously_installed
    ignore_interrupts { previously_linked.link } if previously_linked
    raise
  else
    fi.finish  # this links the new keg
    fi.insinuate
    # if either of these throws an exception, they’ll just have to handle it themselves
  end # reinstall_formula

  def blenderize_options(use_opts, formula)
    def whinge_re_unrecognized(flag)
      puts "Ignoring unrecognized option:  #{flag}"
      if flag[-1] == '='
        alt = flag.chop
        puts "did you mean “#{alt}”?" if formula.option_defined?(alt)
      end
    end # whinge_re_unrecognized

    anti_opts = Options.new
    ARGV.effective_formula_flags.each do |flag|
      flag =~ /^--([^=]+=?)(.+)?$/
      o = Option.new($1)
      unrecognized = false
      if formula.option_defined?(o)
        use_opts << o
      else
        case o.flag
        when /^--with-(.+)$/
          if formula.option_defined?(inverse = "without-#{$1}") or use_opts.include? inverse
            anti_opts << Option.new(inverse)
          else
            unrecognized = true
          end # --with-xxxx?
        when /^--without-(.+)$/
          if formula.option_defined?(inverse = "with-#{$1}") or use_opts.include? inverse
            anti_opts << Option.new(inverse)
          else
            unrecognized = true
          end # --without-xxxx?
        when '--single-arch'
          anti_opts << Option.new('universal')
        when '--universal'
          # the formula doesn’t have a :universal option; ignore it
        when '--stable'
          anti_opts += [Option.new('HEAD'), Option.new('devel')]
        when '--devel'
          use_opts << o
          anti_opts << Option.new('HEAD')
        when '--HEAD'
          use_opts << o
          anti_opts << Option.new('devel')
        else
          flag =~ /^--un-([^=]+=?)(.+)?$/
          if use_opts.include?($1)
            anti_opts << Option.new($1)
          else
            unrecognized = true
          end # un-option?
        end # case
        whinge_re_unrecognized(o.flag) if unrecognized
      end # option is defined?
    end # each ARGV flag
    use_opts - anti_opts
  end # blenderize_options
end # Homebrew
