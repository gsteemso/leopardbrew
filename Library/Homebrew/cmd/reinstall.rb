#:  Usage:  brew reinstall [/formula options/] /installed formula/ [...]
#:
#:Reïnstall each given /installed formula/, using the same options which each one
#:used previously.  Further options may be added, but will apply to all specified
#:formulæ.
#:
#:If multiple current versions are installed (the extreme case being all three of
#:of stable, devel, and HEAD), clarify which one to reïnstall by using or leaving
#:out the usual options and/or the special option “--stable”.  Should you specify
#:a current version that ISN’T already installed, the others will be removed upon
#:success.
#:
#:Active options may be cancelled by specifying their opposite.  A formula brewed
#:--with-A may be reïnstalled --without-A to cancel it; while one --without-B may
#:likewise be reïnstalled --with-B.  (“--universal”, with no obvious antonym, can
#:be cancelled by specifying “--single-arch” or “--no-universal”.)

require 'formula/installer'

module Homebrew
  def reinstall
    raise FormulaUnspecifiedError if ARGV.named.empty?
    raise 'Specify “--HEAD” in uppercase to build from the latest source code.' \
                                                                           if ARGV.include? '--head'
    raise '--ignore-dependencies and --only-dependencies are mutually exclusive.' \
                                                           if ARGV.ignore_deps? and ARGV.only_deps?
    FormulaInstaller.prevent_build_flags unless MacOS.has_apple_developer_tools?
    named_spec = (ARGV.build_head? ? :head :
                   (ARGV.build_devel? ? :devel :
                     (ARGV.include?('--stable') ? :stable :
                       nil) ) )
    puts "Named spec = #{named_spec or '[none]'}" if DEBUG

    ARGV.resolved_formulae.each do |f|
      if f.installed? then reinstall_formula(f, named_spec)
      else
        action = f.any_version_installed? ? 'upgrade' : 'install'
        opoo <<-_.undent.rewrap
          The formula #{f.name} could not be reinstalled because no current version of it is
          installed in the first place.  Instead, use:
              brew #{action} #{f.full_name}
        _
      end
    end
  end # reinstall

  def reinstall_formula(f, s)
    existing_prefixes = f.installed_current_prefixes.values
    puts 'installed current prefixes:', existing_prefixes * ' ' if DEBUG
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
    tab = Tab.for_formula(f) # this gets the tab for the correct installed keg
    options = tab.used_options
    puts "Original spec = #{tab.spec.to_s or '[none]'}" if DEBUG
    case tab.spec
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
    previously_installed = Keg.new(tab.tabfile.parent)
    ignore_interrupts { previously_installed.rename }

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
    fi.finish  # this links the new keg
  rescue FormulaInstallationAlreadyAttemptedError
    # next
  rescue Exception
    # leave no trace of the failed installation
    if f.prefix != previously_installed.path
      if f.prefix.exists?
        oh1 "Cleaning up the failed installation #{f.prefix}" if DEBUG
        ignore_interrupts { f.prefix.rmtree }
      end
      ignore_interrupts { previously_installed.rename }
    end
    ignore_interrupts { previously_linked.link } if previously_linked and not f.linked_keg.directory?
    raise
  else
    ignore_interrupts { previously_installed.path.rmtree } if previously_installed.path.exists? \
                                                              and previously_installed.path != f.prefix
    f.insinuate if f.insinuate_defined?
  end # reinstall_formula

  def blenderize_options(use_opts, formula)
    def whinge_re_unrecognized(flag)
      puts "Ignoring unrecognized option:  #{flag}"
      if flag[-1] == '='
        alt = flag.chop
        puts "did you mean “#{alt}”?" if formula.option_defined?(alt)
      end
    end # whinge_re_unrecognized

    d_o_list = formula.deprecated_options
    anti_opts = Options.new
    use_opts.each do |o|
      if (ix = d_o_list.find_index { |d_o| d_o.old == o.name })
        o = Option.new(d_o_list[ix].current)
      elsif not formula.option_defined?(o)
        anti_opts << o
      end
    end
    ARGV.effective_formula_flags.each do |flag|
      flag =~ OPTION_RX
      o = Option.new($1)
      o.value = $2
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
            anti_opts << Option.new('universal') << Option.new('cross')
            ENV.delete 'HOMEBREW_BUILD_UNIVERSAL'
            ENV.delete 'HOMEBREW_CROSS_COMPILE'
          when '--cross', '--universal'
            # the formula doesn’t have either option; ignore it
          when '--stable'
            anti_opts += [Option.new('HEAD'), Option.new('devel')]
          when '--devel'
            use_opts << o
            anti_opts << Option.new('HEAD')
          when '--HEAD'
            use_opts << o
            anti_opts << Option.new('devel')
          when /^--un-([^=]+=?)(.+)?$/, /^--no-([^=]+=?)(.+)?$/
            anti_opts << Option.new($1) if formula.option_defined?($1) or use_opts.include? $1
            ENV.delete 'HOMEBREW_BUILD_UNIVERSAL' if $1 == 'universal'
            ENV.delete 'HOMEBREW_CROSS_COMPILE'   if $1 == 'cross'
          else
            unrecognized = true
        end # case
        whinge_re_unrecognized(o.flag) if unrecognized
      end # option is defined?
    end # each ARGV flag
    use_opts - anti_opts
  end # blenderize_options
end # Homebrew
