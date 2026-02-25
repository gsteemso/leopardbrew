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

  SWITCHES = { '1' => '--1',  # “do not recurse” – only used by the `deps` command
             # 'd' => '--debug', (already handled as an environment flag)
               'f' => '--force',
               'g' => '--git',
               'i' => '--interactive',
               'n' => '--dry-run',
             # 'q' => '--quieter'  (already handled as an environment flag)
             # 's' => '--build-from-source', (already handled as an environment flag)
             # 'u' => '--universal', (already handled as a build-mode option)
             # 'v' => '--verbose', (already handled as an environment flag)
             # 'x' => '--cross', (already handled as a build‐mode option)
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
                  '--native'      => :n8ive,
                  '--plain'       => :plain,
                  '--single-arch' => :plain, }.freeze

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

  def empty_caches
    @btl_arch = @btl_chk = @casks = @effl = @efffl = @fae = @kegs = @lowr_uniq = @mode = @n = @named = @racks = @res_fae = nil
  end

  def clear; empty_caches; super; end

  def named; @named ||= (self - options_only).select{ |nm| nm.choke }; end

  # Selects both switches (-x) and flags (--xxxx).
  def options_only; select{ |arg| arg.to_s.starts_with?('-') }; end

  def flags_only; select{ |arg| arg.to_s.starts_with?('--') }; end

  # Constructs a list of all the flags which would have needed to be passed to convey every datum which either really was passed as
  # a flag, or was actually passed as a switch or through an environment variable.  There is a special case here, in that all build
  # types (universal and otherwise) are conveyed to the build and test scripts by the “--mode=” flag, but that information can also
  # be relayed by other means, which must be filtered out.  Those parts of our infrastructure which must distinguish the build type
  # do so via the argument to --mode=.
  def effective_flags
    @effl ||= begin
                flags = flags_only.reject{ |flag| flag =~ %r{^--mode=} } - U_MODE_FLAGS
                ENV_FLAGS.each do |s|
                  flag = "--#{s.chop.gsub('_', '-')}"
                  flags << flag if (not includes?(flag) and send s.to_sym)
                end
                flags << "--mode=#{build_mode}"
                SWITCHES.each{ |s, flag| flags << flag if (switch?(s) and not includes? flag) }
                flags
              end
  end # effective_flags

  # Constructs a list of all user-supplied flags not specific to the brewing system; i.e. only those flags that were (or might have
  # been) defined by a specific formula.  This does involve the special case that the assorted flavours of universal build might be
  # specified in any of several ways, but from the Formula’s perspective, are notionally always signalled by a “--universal” flag.
  def effective_formula_flags
    @efffl ||= begin
                 flags = flags_only.reject{ |flag| BREW_SYSTEM_EQS.any?{ |eq| flag =~ /^#{eq}=/ }} - U_MODE_FLAGS
                 flags << "--mode=#{build_mode}"
                 flags - BREW_SYSTEM_FLAGS - SWITCHES.values - ENV_FLAGS.map{ |ef| "--#{ef.chop.gsub('_', '-')}" }
               end
  end # effective_formula_flags

  def formulae
    require 'formula'
    @fae ||= (downcased_unique_named - casks).map{ |name|
        (name.includes?('/') or File.exists? name) ? Formulary.factory(name, spec) : Formulary.find_with_priority(name, spec)
      }
  end # formulae

  def resolved_formulae
    require 'formula'
    @res_fae ||= racks.map{ |r| Formulary.from_rack(r) }.select{ |f| f.any_version_installed? or f.oldname_installed? }
  end

  def casks; @casks ||= downcased_unique_named.grep HOMEBREW_CASK_TAP_FORMULA_REGEX; end

  def racks; @racks ||= downcased_unique_named.map{ |name| if (r = HOMEBREW_CELLAR/name).directory? then r; end }.compact; end

  # Also gathers “kegs” that have no install receipt, so the uninstall command still sees them.
  def kegs
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

  def includes?(arg); @n = find_rindex arg; end  # In the case of conflicting options, we only care about the last one.
  alias_method :include?, :includes?

  def next1; @n and (at(@n + 1) or raise ARGVSyntaxError, 'Missing datum at end of command line'); end

  def value(arg); (@n = find_index{ |o| o =~ /^--#{arg}=(.+)$/ }) ? $1 : includes?("--#{arg}") ? next1 : nil; end

  def debug?; flag? '--debug' or ENV['HOMEBREW_DEBUG'].choke; end

  def force?; flag? '--force'; end

  def git?; flag? '--git'; end

  def interactive?; flag? '--interactive'; end

  def one?; flag? '--1'; end

  def quieter?; flag? '--quieter' or ENV['HOMEBREW_QUIET'].choke; end

  def verbose?; flag? '--verbose' or ENV['VERBOSE'].choke or ENV['HOMEBREW_VERBOSE'].choke; end

  def dry_run?; includes? '--dry-run' or switch? 'n'; end

  def homebrew_developer?; includes? '--homebrew-developer' or ENV['HOMEBREW_DEVELOPER'].choke; end

  def ignore_aids?; includes? '--no-enhancements'; end

  def dep_treatment
    none = ignore_deps?; only = includes?('--only-dependencies')
    raise ArgumentError, '“--ignore-dependencies” and “--only-dependencies” are mutually exclusive' if none and only
    none ? :ignore : only ? :only : false
  end

  def ignore_deps?; includes? '--ignore-dependencies'; end

  def sandbox?; includes? '--sandbox' or ENV['HOMEBREW_SANDBOX'].choke; end

  def json; value 'json'; end

  def build_head?; includes? '--HEAD'; end

  def build_devel?; includes? '--devel'; end

  def build_stable?; includes? '--stable' or (not build_head? and not build_devel?); end

  def build_spec; build_stable? ? :stable : build_devel? ? :devel : :head; end

  def build_cross?;  build_mode == :cross; end

  def build_local?;  build_mode == :local; end

  def build_native?; build_mode == :n8ive; end

  def build_plain?;  build_mode == :bottL or build_mode == :plain; end

  def build_fat?; not build_plain?; end
  alias_method :build_universal?, :build_fat?

  def build_mode
    @mode ||= build_bottle?                            ? :bottL                       : \
              includes?('--universal') or
                value('mode') or
                intersects?(U_MODE_OPTS.keys)          ? universal_mode_with_priority : \
              m = ENV['HOMEBREW_UNIVERSAL_MODE'].choke ? validate_universal_mode(m)   : :plain
  end # build_mode

  def force_universal_mode  # This needs to be kept in sync with BuildOptions#force_universal_mode
    return if build_mode != :plain  # Either it’s already universal & we’ve finished, or it’s :bottL & we can’t in the first place.
    empty_caches
    unshift "--mode=#{build_mode}" unless value('mode')
  end # force_universal_mode

  def build_bottle?; includes? '--build-bottle' or ENV['HOMEBREW_BUILD_BOTTLE'].choke or bottle_arch; end

  def bottle_arch
    unless @btl_chk
      @btl_chk = true
      @btl_arch ||= (arch = value 'bottle-arch') ? arch.to_sym : nil
    end
    @btl_arch
  end # bottle_arch

  def build_from_source?
    indices = [switch?('s'), includes?('--build-from-source'), (-1 if ENV['HOMEBREW_BUILD_FROM_SOURCE'].choke)].compact
    indices.max unless indices.empty?
  end

  def flag?(flag); includes? flag or switch? flag[2, 1]; end

  def force_bottle?; includes? '--force-bottle'; end

  def forced_install_type
    bfs = build_from_source? || -2; fb = force_bottle? || -2
    # These can only be equal if they’re both absent (i.e. nil → -2) – and if --build-from-source is only indicated via environment
    # variable (-1), --force-bottle being present in any position will override it.
    (bfs > fb) ? :source : (fb > bfs) ? :bottle : false
  end

  # eg. `foo -ns -i --bar` has three switches, n, s and i
  def switch?(char)
    return false if char.length > 1
    ropts = options_only.reverse
    if n = ropts.find_index{ |arg| arg[1, 1] != '-' and arg.includes? char } then length - n - 1; end
  end  # reverse before find_index because in the case of conflicting options, we only care about the last one.  (When incompatible
       # switches get passed in the same bundle thereof, it’s the caller’s problem.)  find_rindex inexplicably fails here and can’t
       # be used (something to do with the block being passed).

  def usage; require 'cmd/help'; Homebrew.help_s; end

  def cc; value 'cc'; end

  def env; value 'env'; end

  # If the user passes any flags that trigger building over installing from a bottle, they’re collected here & returned as an Array
  # for examination.
  def collect_build_flags
    build_flags = []
    build_flags << '--HEAD' if build_head?
    build_flags << '--universal' << "--mode=#{build_mode}" if build_fat?
    build_flags << '--build-bottle' if build_bottle?
    build_flags << '--build-from-source' if build_from_source?
    build_flags
  end # collect_build_flags

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
    options_only.reverse_each do |opt|
      case opt
        when '--universal', '-u' then return (m = ENV['HOMEBREW_UNIVERSAL_MODE'].choke) \
                                               ? validate_universal_mode(m) \
                                               : Target.default_universal_mode
        when *U_MODE_OPTS.keys   then return U_MODE_OPTS[opt]
        when %r{^--mode=(.+)$}   then return validate_universal_mode($1)
      end
    end # each option |opt| in reverse order
    nil
  end # universal_mode_with_priority

  def validate_universal_mode(m)
    case m.to_s.downcase
      when 'cross'  then :cross
      when 'local'  then :local
      when 'native' then :n8ive
      else               :plain
    end
  end # validate_universal_mode
end # HomebrewArgvExtension
