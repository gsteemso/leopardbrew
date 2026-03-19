# This file is loaded before 'global.rb', so must eschew most Homebrew‐isms at eval time.
module HomebrewArgvExtension

  private

  ENV_FLAGS = %w[ build_bottle?
                  build_from_source?
                  debug?
                  homebrew_developer?
                  quieter?
                  sandbox?
                  verbose?            ].freeze

  SWITCHES = { '--1'                 => nil, # “do not recurse” – only used by `deps` and `uses`
             # '--debug'             => nil, (already handled as an environment flag)
               '--force'             => nil,
               '--git'               => nil,
               '--interactive'       => nil,
               '--dry-run'           => 'n',
             # '--quieter'           => nil, (already handled as an environment flag)
               '--recursive'         => nil,
             # '--build-from-source' => 's', (already handled as an environment flag)
             # '--universal'         => nil, (already handled as a build-mode option)
             # '--verbose'           => nil, (already handled as an environment flag)
             # '--cross'             => 'x', (already handled as a build‐mode option)
             }.freeze

  U_MODE_FLAGS = %w[ --cross
                     --local
                     --native
                     --plain
                     --universal
                     --single-arch ].freeze

  U_MODE_OPTS = { '--cross'       => :cross,
                  '-x'            => :cross,
                  '--local'       => :local,
                  '--native'      => :native,
                  '--plain'       => :plain,
                  '--single-arch' => :plain,  }.freeze

  BREW_SYSTEM_EQS = %w[ --bottle-arch
                        --cc
                        --env
                        --json
                        --mode        ].freeze

  BREW_SYSTEM_FLAGS = %w[ --force-bottle
                          --ignore-dependencies
                          --no-enhancements
                          --only-dependencies   ].freeze

  public

# Methods without return values:

  def clear; empty_caches; super; end

  def empty_caches
    @btl_arch = @btl_chk = @casks = @effl = @efffl = @fae = @kegs = @lowr_uniq = @mode = @n = @named = @racks = @res_fae = nil
  end

  # This must be kept in sync with BuildOptions#force_universal_mode.  Do note, the caller must first ensure that universal mode is
  # in fact permitted for this to have any effect.
  def force_universal_mode
    return if build_mode != :plain  # Either it’s already universal & we’ve finished, or it’s :bottle & we can’t in the first place.
    # Ensure there is a fallback, but only alter the environment if we’re attached to ARGV rather than to a formula’s BuildOptions.
    if self == ARGV and not ENV['HOMEBREW_UNIVERSAL_MODE'].choke
      ENV['HOMEBREW_UNIVERSAL_MODE'] = Target.default_universal_mode.to_s
    end
    empty_caches
    temp = build_mode.to_s  # Repopulate the build‐mode cache.
    # Only alter the environment if we are attached to ARGV rather than to a formula’s BuildOptions.
    ENV['HOMEBREW_BUILD_MODE'] = temp if self == ARGV
  end # force_universal_mode


# Utility methods used by most of the others:

# In the case of conflicting options, we only care about the last one, so all of these look for that.  (Incompatible switches found
# in the same bundle thereof are the caller’s problem.)
# Note:  The block form of find_rindex inexplicably fails, and can’t be used here until we figure out why.

  def flag?(fl, sw = fl[2]); indices = [includes?(fl), switch?(sw || fl[2])].compact; indices.max unless indices.empty?; end

  def includes?(arg); @n = find_rindex arg; end
  alias_method :include?, :includes?

  def n_after(method, *args); send(method, *args); @n; end

  def next1; @n and (at(@n + 1) or raise ARGVSyntaxError, 'Missing datum at end of command line'); end

  def switch?(char)  # eg. `foo -ns -i --bar` has three switches, n, s and i
    return false if char.length > 1 or char == '-'
    @n = find_rindex{ |arg| arg[0] == '-' and arg[1] != '-' and arg.includes? char }
  end

  def value(flag)
    (@n = find_rindex{ |o| o =~ /^--#{flag}=(.+)$/ }) ? $1 : includes?("--#{flag}") ? next1 : nil
  end


# Predicates.  Most of them return the index of the datum they test for, or at least set @n to it.

  def build_bottle?
    indices = [includes?('--build-bottle'), n_after(:value, '--bottle-arch'), (-1 if ENV['HOMEBREW_BUILD_BOTTLE'].choke)].compact
    indices.max unless indices.empty?
  end

  def build_cross?;  build_mode == :cross;  end

  def build_devel?; includes? '--devel'; end

  def build_fat?; not build_plain?; end
  alias_method :build_universal?, :build_fat?

  def build_from_source?
    indices = [flag?('--build-from-source', 's'), (-1 if ENV['HOMEBREW_BUILD_FROM_SOURCE'].choke)].compact
    indices.max unless indices.empty?
  end

  def build_head?; includes? '--HEAD'; end

  def build_local?;  build_mode == :local;  end

  def build_native?; build_mode == :native; end

  def build_plain?;  build_mode == :bottle or build_mode == :plain; end

  def build_stable?; includes? '--stable' or (not build_head? and not build_devel?); end

  def debug?; flag? '--debug' or ENV['HOMEBREW_DEBUG'].choke; end

  def dry_run?; flag? '--dry-run', 'n'; end

  def force?; flag? '--force'; end

  def force_bottle?; includes? '--force-bottle'; end

  def git?; flag? '--git'; end

  def homebrew_developer?; includes? '--homebrew-developer' or ENV['HOMEBREW_DEVELOPER'].choke; end

  def ignore_aids?; includes? '--no-enhancements'; end

  def ignore_deps?; includes? '--ignore-dependencies'; end

  def interactive?; flag? '--interactive'; end

  def one?; flag? '--1'; end

  def quieter?; flag? '--quieter' or ENV['HOMEBREW_QUIET'].choke; end

  def recursive?; flag? '--recursive'; end

  def sandbox?; includes? '--sandbox' or ENV['HOMEBREW_SANDBOX'].choke; end

  def verbose?; flag? '--verbose' or ENV['VERBOSE'].choke or ENV['HOMEBREW_VERBOSE'].choke; end


# Methods returning a single datum:

  def bottle_arch
    unless @btl_chk
      @btl_chk = true
      @btl_arch ||= (arch = value 'bottle-arch') ? arch.to_sym : ENV['HOMEBREW_BUILD_BOTTLE'].choke
    end
    @btl_arch
  end # bottle_arch

  def build_mode
    @mode ||= (m = ENV['HOMEBREW_BUILD_MODE'].choke)     ? validate_build_mode(m)       : \
              build_bottle?                              ? :bottle                      : \
              (includes?('--universal') or
                value('mode') or
                intersects? U_MODE_OPTS.keys)            ? universal_mode_with_priority : \
              (m = ENV['HOMEBREW_UNIVERSAL_MODE'].choke) ? validate_universal_mode(m)   : :plain
  end # build_mode

  def build_spec; build_stable? ? :stable : build_devel? ? :devel : :head; end

  def cc; value 'cc'; end

  def dep_treatment
    none = ignore_deps?; only = includes?('--only-dependencies')
    raise ArgumentError, '“--ignore-dependencies” and “--only-dependencies” are mutually exclusive' if none and only
    none ? :ignore : only ? :only : false
  end

  def env; value 'env'; end

  def forced_install_type
    bfs = build_from_source? || -2; fb = force_bottle? || -2
    # These can only be equal if they’re both absent (i.e. nil → -2) – and if --build-from-source is only indicated via environment
    # variable (-1), --force-bottle being present in any position will override it.
    (bfs > fb) ? :source : (fb > bfs) ? :bottle : false
  end

  def json; value 'json'; end

  def recursion; o = one?; r = recursive?; o ? (r ? (o > r ? :no : :yes) : :no) : (r ? :yes : false); end

  def usage; require 'cmd/help'; Homebrew.help_s; end

  def verbosity; quieter? ? :less : verbose? ? :full : false; end


# Methods returning a synthesized aggregate datum:

  # If the user passes any flags that trigger building over installing from a bottle, they’re collected here & returned as an Array
  # for examination.
  def collect_build_flags
    build_flags = []
    build_flags << '--HEAD'              if build_head?
    build_flags << '--universal'         if build_fat?
    build_flags << '--build-bottle'      if build_bottle?
    build_flags << '--build-from-source' if build_from_source?
    build_flags
  end # collect_build_flags

  # Constructs a list of all the flags which would have needed to be passed to convey every datum which either really was passed as
  # a flag, or was actually passed as a switch or through an environment variable.  There is a special case here, in that all build
  # types (universal and otherwise) are conveyed to the build and test scripts by an environment variable, not a flag.  Each of the
  # user‐insertable flags for controlling that variable must be filtered out.
  def effective_flags
    @effl ||= begin
                flags = flags_only.reject{ |flag| flag =~ %r{^--mode=} } - U_MODE_FLAGS
                ENV_FLAGS.each do |s|
                  flag = "--#{s.chop.gsub('_', '-')}"
                  flags << flag if (not includes?(flag) and send s.to_sym)
                end
                SWITCHES.each_pair{ |flag, s| flags << flag if flag?(flag, s) and not includes? flag }
                flags
              end
  end # effective_flags

  # Constructs a list of all user-supplied flags not specific to the brewing system; i.e. only those flags that were (or might have
  # been) defined by a specific formula.  The build mode is conveyed separately.
  def effective_formula_flags
    @efffl ||= flags_only.reject{ |flag| BREW_SYSTEM_EQS.any?{ |eq| flag =~ /^#{eq}=/ }} - U_MODE_FLAGS - BREW_SYSTEM_FLAGS \
                 - SWITCHES.keys - ENV_FLAGS.map{ |ef| "--#{ef.chop.gsub('_', '-')}" }
  end # effective_formula_flags


# Methods returning a collated aggregate datum:

  def casks; @casks ||= downcased_unique_named.grep HOMEBREW_CASK_TAP_FORMULA_REGEX; end

  def flags_only; select{ |arg| arg.to_s.starts_with?('--') }; end

  def formulae
    require 'formula'
    @fae ||= (downcased_unique_named - casks).map{ |name|
        (name.includes?('/') or File.exists? name) ? Formulary.factory(name, spec) : Formulary.find_with_priority(name, spec)
      }
  end # formulae

  def kegs  # Also gathers “kegs” that have no install receipt, so the uninstall command still sees them.
    require 'formula'
    @kegs ||= downcased_unique_named.collect do |name|
        keg = if name =~ VERSIONED_NAME_REGEX
            keg_path = HOMEBREW_CELLAR/$1/$2
            raise NoSuchKegError, name unless keg_path.directory?
            Keg.new(keg_path)
          elsif (f, ss = attempt_factory name) != nil
            if (pn = f.opt_prefix).symlink? and pn.directory? then Keg.new(pn.resolved_path)
            elsif (pn = f.linked_keg).symlink? and pn.directory? then Keg.new(pn.resolved_path)
            elsif (pn = f.spec_prefix(ss)) and pn.directory? then Keg.new(pn)
            elsif (rack = f.rack).directory?
              case (dirs = rack.subdirs).length
                when 0 then raise FormulaNotInstalledError, rack.basename   # not necessarily “name”
                when 1 then Keg.new(dirs.first)
                else # Note that Formula#greatest_installed_keg can fail if there are no install receipts.
                  (k = f.greatest_installed_keg) ? k : raise(MultipleVersionsInstalledError, rack.basename)  # not always “name”
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

  def named; @named ||= (self - options_only).select{ |nm| nm.choke }; end

  def options_only; select{ |arg| arg.to_s.starts_with?('-') }; end  # Selects both switches (-x) and flags (--xxxx).

  def racks; @racks ||= downcased_unique_named.map{ |name| if (r = HOMEBREW_CELLAR/name).directory? then r; end }.compact; end

  def resolved_formulae
    require 'formula'
    @res_fae ||= racks.map{ |r| Formulary.from_rack(r) }.select{ |f| f.any_version_installed? or f.oldname_installed? }
  end

  private

  def attempt_factory(name)
    f = ssym = nil
    [:head, :devel, :stable].find{ |ss| f = Formulary.factory(name, ssym = ss) }
    return [f, ssym]
  rescue FormulaUnavailableError
    return nil
  end

  def downcased_unique_named
    # Only downcase names – pass paths, bottle filenames and URLs unaltered
    @lowr_uniq ||= named.map{ |arg|
        if arg.includes? '/' or arg =~ /\.tar\..{2,4}$/ then arg
        else arg.downcase; end
      }.compact.uniq
  end # downcased_unique_named

  def spec(default = :stable); build_head? ? :head : build_devel? ? :devel : default; end

  def universal_mode_with_priority
    n = length
    options_only.reverse_each do |opt|
      n = n - 1
      case opt
        when '--universal', '-u' then if (m = ENV['HOMEBREW_UNIVERSAL_MODE'].choke)
                                        @n = nil; return validate_universal_mode m
                                      else @n = n; return Target.default_universal_mode; end
        when *U_MODE_OPTS.keys   then @n = n; return U_MODE_OPTS[opt]
        when %r{^--mode=(.+)$}   then @n = n; return validate_build_mode($1)
      end
    end # each option |opt| in reverse order
    @n = nil
  end # universal_mode_with_priority

  def validate_build_mode(m)
    if %w[bottle cross local native plain].include?(m_ = m.to_s.downcase) then m_.to_sym
    else raise ArgumentError, "build mode “#{m.inspect}” not recognized"; end
  end

  def validate_universal_mode(m)
    if %w[cross local native].include?(m_ = m.to_s.downcase) then m_.to_sym
    else raise ArgumentError, "universal (multi‐architecture) build mode “#{m.inspect}” not recognized"; end
  end
end # HomebrewArgvExtension
