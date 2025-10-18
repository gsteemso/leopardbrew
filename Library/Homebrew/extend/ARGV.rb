# This file is loaded before 'global.rb', so must eschew most Homebrew‐isms at eval time.
module HomebrewArgvExtension

  private

  ENV_FLAGS = %w[ build_bottle?
                  build_from_source?
                  debug?
                  homebrew_developer?
                  quieter?
                  sandbox?
                  verbose?  ].freeze

  SWITCHES = { '1' => '--1', # (“do not recurse” – only used by the `deps` command)
             # 'd' => '--debug', (already handled as an environment flag)
               'f' => '--force',
               'g' => '--git',
               'i' => '--interactive',
               'n' => '--dry-run',
             # 'q' => '--quieter'  (already handled as an environment flag)
             # 's' => '--build-from-source', (already handled as an environment flag)
             # 'u' => '--universal', (already handled as a hashed environment flag)
             # 'v' => '--verbose', (already handled as an environment flag)
             # 'x' => '--cross', (already handled as a hashed environment flag)
             }.freeze

  BREW_SYSTEM_EQS = %w[ --bottle-arch=
                        --cc=
                        --env=
                        --json=        ].freeze

  BREW_SYSTEM_FLAGS = %w[ --force-bottle
                          --ignore-dependencies
                          --no-enhancements
                          --only-dependencies   ].freeze

  public

  def clear
    @btl_arch = @btl_chk = @casks = @effl = @efffl = @fae = @kegs = @lowr_uniq = @n = @named = @racks = @res_fae = nil
    super
  end

  def named; @named ||= (self - options_only).select{ |nm| nm.choke }; end

  # Selects both switches (-x) and flags (--xxxx).
  def options_only; select{ |arg| arg.to_s.starts_with?('-') }; end

  def flags_only; select{ |arg| arg.to_s.starts_with?('--') }; end

  # Constructs a list of all the flags which would have needed to be passed to convey every datum which either really was passed as
  # a flag, or was actually passed as a switch or through an environment variable.  There is a special case here, in that cross and
  # universal builds are both conveyed by a “--universal” flag; those parts of the brewing infrastructure which need to distinguish
  # them do so via the presence or absence of “--cross”.
  def effective_flags
    @effl ||= begin
                flags = flags_only - ['--cross', '--universal']
                ENV_FLAGS.each do |s|
                  flag = "--#{s.gsub('_', '-').chop}"
                  flags << flag if (not include?(flag) and send s.to_sym)
                end
                flags << '--universal' if build_fat?
                flags << '--cross' if build_cross?
                SWITCHES.each{ |s, flag| flags << flag if (switch?(s) and not include? flag) }
                flags
              end
  end # effective_flags

  # Constructs a list of all user-supplied flags not specific to the brewing system; i.e. only those flags that were (or might have
  # been) defined by a specific formula.  This does involve a special case in that universal and cross builds can also be specified
  # by switch or by environment variable, and in either case are indicated by a “--universal” flag from the Formula’s point of view.
  def effective_formula_flags
    @efffl ||= begin
                 flags = flags_only.reject{ |flag| BREW_SYSTEM_EQS.any?{ |eq| flag =~ /^#{eq}/ }} - ['--cross', '--universal']
                 flags << '--universal' if build_fat?
                 flags << '--cross' if build_cross?
                 flags - BREW_SYSTEM_FLAGS - SWITCHES.values - ENV_FLAGS.map{ |ef| "--#{ef.gsub('_', '-').chop}" }
               end
  end # effective_formula_flags

  def formulae
    require 'formula'
    @fae ||= (downcased_unique_named - casks).map{ |name|
        if name.include?('/') or File.exists?(name) then Formulary.factory(name, spec)
        else Formulary.find_with_priority(name, spec); end
      }
  end # formulae

  def resolved_formulae
    require 'formula'
    @res_fae ||= racks.map{ |r| Formulary.from_rack(r) }.select{ |f|
        f.any_version_installed? or f.oldname_installed?
      }
  end # resolved_formulae

  def casks; @casks ||= downcased_unique_named.grep HOMEBREW_CASK_TAP_FORMULA_REGEX; end

  def racks
    @racks ||= downcased_unique_named.map{ |name|
        if (r = HOMEBREW_CELLAR/name).directory? then r
        else raise NoSuchRackError, name; end
      }
  end # racks

  # Also gathers “kegs” that have no install receipt, so the uninstall command still sees them.
  def kegs
    require 'formula'
    @kegs ||= downcased_unique_named.collect do |name|
        keg = if name =~ VERSIONED_NAME_REGEX
            keg_path = HOMEBREW_CELLAR/$1/$2
            raise NoSuchKegError, name unless keg_path.directory?
            Keg.new(keg_path)
          elsif (f, ss = attempt_factory(name)) != nil
            if (pn = f.opt_prefix).symlink? and pn.directory? then Keg.new(pn.resolved_path)
            elsif (pn = f.linked_keg).symlink? and pn.directory? then Keg.new(pn.resolved_path)
            elsif (pn = f.spec_prefix(ss)) and pn.directory? then Keg.new(pn)
            elsif (rack = f.rack).directory?
              case (dirs = rack.subdirs).length
                when 0 then raise FormulaNotInstalledError, rack.basename   # not necessarily “name”
                when 1 then Keg.new(dirs.first)
                else
                  if (k = f.greatest_installed_keg) then k        # can fail if no install receipts
                  else raise MultipleVersionsInstalledError, rack.basename  # not necessarily “name”
                  end
              end
            end
          else # no formula
            rack = HOMEBREW_CELLAR/name
            raise NoSuchRackError, name unless rack.directory?
            case (dirs = rack.subdirs).length
              when 0 then raise FormulaNotInstalledError, name
              when 1 then Keg.new(dirs.first)
              else raise MultipleVersionsInstalledError, name
            end
          end # keg? formula?
      end.compact  # end of kegs = ...collect do
  end # kegs

  def include?(arg); @n = index arg; end

  def next1; @n and at(@n + 1) or raise(UsageError); end

  def value(arg)
    if find{ |o| o =~ /^--#{arg}=(.+)$/ } then $1
    elsif include?("--#{arg}") then next1; end
  end

  def debug?; flag? '--debug' or ENV['HOMEBREW_DEBUG'].choke; end

  def force?; flag? '--force'; end

  def git?; flag? '--git'; end

  def interactive?; flag? '--interactive'; end

  def one?; flag? '--1'; end

  def quieter?; flag? '--quieter' or ENV['HOMEBREW_QUIET'].choke; end

  def verbose?; flag? '--verbose' or ENV['VERBOSE'].choke or ENV['HOMEBREW_VERBOSE'].choke; end

  def dry_run?; include? '--dry-run' or switch? 'n'; end

  def homebrew_developer?; include? '--homebrew-developer' or ENV['HOMEBREW_DEVELOPER'].choke; end

  def ignore_aids?; include? '--no-enhancements'; end

  def ignore_deps?; include? '--ignore-dependencies'; end

  def only_deps?; include? '--only-dependencies'; end

  def sandbox?; include? '--sandbox' or ENV['HOMEBREW_SANDBOX'].choke; end

  def json; value 'json'; end

  def build_head?; include? '--HEAD'; end

  def build_devel?; include? '--devel'; end

  def build_stable?; include? '--stable' or (not build_head? and not build_devel?); end

  def build_cross?; include? '--cross' or switch? 'x' or ENV['HOMEBREW_UNIVERSAL_MODE'].to_s.downcase == 'cross'; end

  def build_universal?; ENV['HOMEBREW_UNIVERSAL_MODE'].to_s.downcase == 'local' or flag? '--universal'; end

  def build_fat?; build_universal? or build_cross?; end

  def build_mode; build_cross? ? :cross : build_universal? ? :local : :plain; end

  # Request a 32-bit only build.  Needed for some use-cases.  Building Universal is preferable.
  def build_32_bit?; include? '--32-bit'; end

  def build_bottle?; include? '--build-bottle' or ENV['HOMEBREW_BUILD_BOTTLE'].choke or bottle_arch; end

  def bottle_arch
    unless @btl_chk
      @btl_chk = true
      @btl_arch ||= if (arch = value 'bottle-arch') then arch.to_sym; end
    end
    @btl_arch
  end # bottle_arch

  def build_from_source?
    switch? 's' or include? '--build-from-source' or ENV['HOMEBREW_BUILD_FROM_SOURCE'].choke
  end

  def flag?(flag); include? flag or switch? flag[2, 1]; end

  def force_bottle?; include? '--force-bottle'; end

  # eg. `foo -ns -i --bar` has three switches, n, s and i
  def switch?(char)
    return false if char.length > 1
    options_only.any?{ |arg| arg[1, 1] != '-' and arg.includes? char }
  end

  def usage; require 'cmd/help'; Homebrew.help_s; end

  def cc; value 'cc'; end

  def env; value 'env'; end

  # If the user passes any flags that trigger building over installing from a bottle, they’re collected here & returned as an Array
  # for examination.
  def collect_build_flags
    build_flags = []
    build_flags << '--HEAD' if build_head?
    build_flags << '--universal' if build_fat?
    build_flags << '--32-bit' if build_32_bit?
    build_flags << '--build-bottle' if build_bottle?
    build_flags << '--build-from-source' if build_from_source?
    build_flags
  end # collect_build_flags

  private

  def spec(default = :stable)
    if build_head? then :head
    elsif build_devel? then :devel
    else default; end
  end

  def downcased_unique_named
    # Only downcase names – pass paths, bottle filenames and URLs unaltered
    @lowr_uniq ||= named.map{ |arg|
        if arg.include? '/' or arg =~ /\.tar\..{2,4}$/ then arg
        else arg.downcase; end
      }.compact.uniq
  end # downcased_unique_named

  def attempt_factory(name)
    f = ssym = nil
    [:head, :devel, :stable].find{ |ss| f = Formulary.factory(name, ssym = ss) }
    return [f, ssym]
  rescue FormulaUnavailableError
    return nil
  end
end # HomebrewArgvExtension
