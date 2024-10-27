module HomebrewArgvExtension

  private

  ENV_FLAGS = %w[
    build_bottle?
    build_from_source?
    debug?
    homebrew_developer?
    quieter?
    sandbox?
    verbose?
  ].freeze

  ENV_F_FLAG_HASH = { 'build_universal?' => '--universal' }.freeze

  SWITCHES = {
    '1' => '--1', # (“do not recurse” – only used by the `deps` command)
  # 'd' => '--debug' (already handled as an ENV_ARG)
    'f' => '--force',
    'g' => '--git',
    'i' => '--interactive',
    'n' => '--dry-run',
  # 'q' => '--quieter'  (already handled as an ENV_ARG)
  # 's' => '--build-from-source' (already handled as an ENV_ARG)
  # 'u' => '--universal' (already handled as an ENV_ARG)
  # 'v' => '--verbose' (already handled as an ENV_ARG)
  }.freeze

  BREW_SYSTEM_EQS = %w[
    --bottle-arch=
    --cc=
    --env=
    --json=
  ].freeze

  BREW_SYSTEM_FLAGS = %w[
    --force-bottle
    --ignore-dependencies
    --only-dependencies
  ].freeze

  public

  def clear
    @casks = @downcased_unique_named = @formulae = @kegs = @n = @named = @resolved_formulae = nil
    super
  end

  def named
    @named ||= self - options_only
  end

  def options_only
    select { |arg| arg.to_s.starts_with?('-') }
  end

  def flags_only
    select { |arg| arg.to_s.starts_with?('--') }
  end

  def effective_flags
    flags = flags_only
    ENV_FLAGS.each do |a|
      flag = "--#{a.gsub('_', '-').chop}"
      flags << flag if (not(include? flag) and send a.to_sym)
    end
    ENV_F_FLAG_HASH.each { |method, flag| flags << flag if (not(include? flag) and send method.to_sym) }
    SWITCHES.each do |s, flag|
      flags << flag if (switch?(s) and not include? flag)
    end
    flags
  end # effective_flags

  def effective_formula_flags
    flags = flags_only.reject { |f| BREW_SYSTEM_EQS.any? { |eq| f =~ /^#{eq}/ } }
    ENV_F_FLAG_HASH.each { |method, flag| flags << flag if (not(include? flag) and send method.to_sym) }
    flags - BREW_SYSTEM_FLAGS
  end

  def formulae
    require 'formula'
    @formulae ||= (downcased_unique_named - casks).map do |name|
      if name.include?('/') or File.exist?(name)
        Formulary.factory(name, spec)
      else
        Formulary.find_with_priority(name, spec)
      end
    end
  end # formulae

  def resolved_formulae
    require 'formula'
    @resolved_formulae ||= (downcased_unique_named - casks).map do |name|
      if name.include?('/')
        f = Formulary.factory(name, spec)
        if spec(default=nil).nil? and f.installed?
          installed_spec = Tab.for_formula(f).spec
          f.set_active_spec(installed_spec) if f.send(installed_spec)
        end
        f
      else
        rack = Formulary.to_rack(name)
        Formulary.from_rack(rack, spec(default=nil))
      end
    end
  end # resolved_formulae

  def casks
    @casks ||= downcased_unique_named.grep HOMEBREW_CASK_TAP_FORMULA_REGEX
  end

  # this also gathers “kegs” that have no install receipt, so the uninstall command still sees them
  def kegs
    require 'keg'
    require 'formula'
    @kegs ||= downcased_unique_named.collect do |name|
      ss = spec
      f = Formulary.factory(name, ss)
      rack = f.rack
      dirs = rack.directory? ? rack.subdirs : []
      rackname = rack.basename
      raise NoSuchKegError.new(rackname) if dirs.empty?
      ss = f.active_spec_sym
      raise NoSuchKegError.new(rackname/sip.basename) unless (sip = f.spec_iprefix(ss)).directory?
      if f.installed?(ss)
        Keg.new(sip)
      elsif (var = f.opt_prefix).symlink? and var.directory?
        Keg.new(var.resolved_path)
      elsif (var = f.linked_keg).symlink? and var.directory?
        Keg.new(var.resolved_path)
      elsif dirs.length == 1
        Keg.new(dirs.first)
      elsif f.iprefix.directory?
        Keg.new(f.iprefix)
      else
        raise MultipleVersionsInstalledError.new(rackname)
      end
    end
  end # kegs

  def versioned_kegs
    require 'keg'
    require 'formulary'
    require 'tab'
    @kegs ||= downcased_unique_named.collect { |name|
      rack = Formulary.to_rack(name)
      dirs = rack.directory? ? rack.subdirs : []
      raise NoSuchKegError.new(rack.basename) if dirs.empty?
      kegs = []
      dirs.each { |d| kegs << Keg.new(d) if (d/Tab::FILENAME).exists? }
      kegs
    }.flatten
  end # versioned_kegs

  # self documenting perhaps?
  def include?(arg)
    @n = index arg
  end

  def next
    at(@n+1) or raise(UsageError)
  end

  def value(arg)
    arg = find { |o| o =~ /--#{arg}=(.+)/ }
    $1 if arg
  end

  def force?
    flag? '--force'
  end

  def verbose?
    flag?('--verbose') or not(ENV['VERBOSE'].nil?) or not ENV['HOMEBREW_VERBOSE'].nil?
  end

  def debug?
    flag?('--debug') or not ENV['HOMEBREW_DEBUG'].nil?
  end

  def quieter?
    flag? '--quieter' or not ENV['HOMEBREW_QUIET'].nil?
  end

  def interactive?
    flag? '--interactive'
  end

  def one?
    flag? '--1'
  end

  def dry_run?
    include?('--dry-run') or switch?('n')
  end

  def git?
    flag? '--git'
  end

  def homebrew_developer?
    include?('--homebrew-developer') or not ENV['HOMEBREW_DEVELOPER'].nil?
  end

  def sandbox?
    include?('--sandbox') or not ENV['HOMEBREW_SANDBOX'].nil?
  end

  def ignore_deps?
    include? '--ignore-dependencies'
  end

  def only_deps?
    include? '--only-dependencies'
  end

  def json
    value 'json'
  end

  def build_head?
    include? '--HEAD'
  end

  def build_devel?
    include? '--devel'
  end

  def build_stable?
    not (build_head? or build_devel?)
  end

  def build_universal?
    flag? '--universal' or not ENV['HOMEBREW_BUILD_UNIVERSAL'].nil?
  end

  # Request a 32-bit only build.
  # This is needed for some use-cases though we prefer to build Universal
  # when a 32-bit version is needed.
  def build_32_bit?
    include? '--32-bit'
  end

  def build_bottle?
    include?('--build-bottle') or not ENV['HOMEBREW_BUILD_BOTTLE'].nil?
  end

  def bottle_arch
    arch = value 'bottle-arch'
    arch.to_sym if arch
  end

  def build_from_source?
    switch?('s') or include?('--build-from-source') or not ENV['HOMEBREW_BUILD_FROM_SOURCE'].nil?
  end

  def flag?(flag)
    include?(flag) or switch?(flag[2, 1])
  end

  def force_bottle?
    include? '--force-bottle'
  end

  # eg. `foo -ns -i --bar` has three switches, n, s and i
  def switch?(char)
    return false if char.length > 1
    options_only.any? { |arg| arg[1, 1] != '-' and arg.include?(char) }
  end

  def usage
    require 'cmd/help'
    Homebrew.help_s
  end

  def cc
    value 'cc'
  end

  def env
    value 'env'
  end

  # If the user passes any flags that trigger building over installing from
  # a bottle, they are collected here and returned as an Array for checking.
  def collect_build_flags
    build_flags = []

    build_flags << '--HEAD' if build_head?
    build_flags << '--universal' if build_universal?
    build_flags << '--32-bit' if build_32_bit?
    build_flags << '--build-bottle' if build_bottle?
    build_flags << '--build-from-source' if build_from_source?

    build_flags
  end # collect_build_flags

  private

  def spec(default = :stable)
    if build_head?
      :head
    elsif build_devel?
      :devel
    else
      default
    end
  end # spec

  def downcased_unique_named
    # Only lowercase names, not paths, bottle filenames or URLs
    @downcased_unique_named ||= named.map do |arg|
      if arg.include?('/') or arg =~ /\.tar\..{2,4}$/
        arg
      else
        arg.downcase
      end
    end.uniq
  end # downcased_unique_named
end # HomebrewArgvExtension
