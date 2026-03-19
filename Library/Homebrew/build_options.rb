class BuildOptions
  attr_accessor :s_args, :options

  # Note that argument options not actually defined by the formula may be carried by a BuildOptions object.  This allows techniques
  # such as the (now obsolete) insertion of --universal flags for formulæ that define no universal option because they always build
  # :universal.

  # This method expects two Options objects.
  # @private
  def initialize(arg_options, defined_options)
    @o_args = arg_options
    @s_args = @o_args.map{ |o| o.to_s }.extend(HomebrewArgvExtension)
    @options = defined_options
  end

  def fix_deprecation(deprecated_option)
    if i = s_args.index(deprecated_option.old_flag)
      s_args[i] = deprecated_option.current_flag
      @o_args = @o_args - Option.new(deprecated_option.old)
      @o_args << Option.new(deprecated_option.current)
    end
  end # fix_deprecation()

  # True if a {Formula} is being built with a specific option, one not necessarily named “with-*” or “without-*”.
  # @deprecated
  def include?(val); s_args.include?("--#{val}"); end
  alias_method :includes?, :include?

  # True if a {Formula} is being built with a specific option.
  #   args << '--i-want-spam' if build.with? 'spam'
  #   args << '--qt-gui' if build.with? 'qt' # '--with-qt' ==> build.with? 'qt'
  # If a formula presents a user with a choice, but the choice must be fulfilled:
  #   args << (build.with?('example2') ? '--with-example2' : '--with-example1')
  def with?(val)
    name = case val
        when Dependency, Requirement then val.option_name
        when Option                  then val.name
        else                              val.to_s
      end
    if option_defined?("with-#{name}") then includes?("with-#{name}")
    elsif option_defined?("without-#{name}") then not includes?("without-#{name}")
    else false; end
  end # with?

  # True if a {Formula} is being built without a specific option.
  #   args << '--no-spam-plz' if build.without? 'spam'
  def without?(val); not with? val; end

  # True if a {Formula} is being built as a bottle (i.e. binary package).
  def bottle?; s_args.build_bottle?; end

  # True if a {Formula} is being built with {#head} instead of {#stable}.
  #   args << '--some-new-stuff' if build.head?
  # If there are multiple conditional arguments, use a block.
  #  if build.head?
  #    args << '--i-want-pizza'
  #    args << '--and-a-cold-beer' if build.with? 'cold-beer'
  #  end
  def head?; s_args.build_head?; end

  # True if a {Formula} is being built with {#devel} instead of {#stable}.
  #   args << '--some-beta' if build.devel?
  def devel?; s_args.build_devel?; end

  # True if a {Formula} is being built with {#stable}, not {#devel} or {#head}.  This is the default.
  #   args << '--some-beta' if build.devel?
  def stable?; s_args.build_stable?; end

  def cxx11?; opoo 'The BuildOptions#cxx11? method is obsolete.  Something needs adjustment.'; false; end

  # Like ARGV#build_mode, but validated against the actual options on offer.
  def mode
    if option_defined?('cross')  # The only option defined in every fat‐build environment.
      if option_defined?((bm = s_args.build_mode).to_s) then bm
      elsif bm == :local
        if Target.local_archs == Target.native_archs then (option_defined? 'native') ? :native : :plain
        elsif Target.local_archs == Target.cross_archs then :cross; end
      end
    else bottle? ? :bottle : :plain; end
  end # mode

  # True if a {Formula} is being built as a universal binary, whether native‐only, locally‐oriented, or cross‐compiled.
  #   ENV.universal_binary if build.universal?
  def universal?; s_args.build_universal? and option_defined?('cross'); end
  alias_method :fat?, :universal?

  # True if a {Formula} is being built for multiple platforms.
  def cross?; universal? and mode == :cross; end

  # True if a {Formula} is being built for all local architectures.
  # e.g. on Intel under Snow Leopard this means a combined ppc/i386/x86_64 binary or library.
  def local?; universal? and mode == :local; end

  # True if a {Formula} is being built for native architectures only (those which can be run without emulation).
  # e.g. on Intel under Tiger through Snow Leopard this means a combined i386/x86_64 binary or library.
  def native?; universal? and mode == :native; end

  # What it says.  Must be kept in sync with the version in extend/ARGV.  For formulæ that always build universal, & as such do not
  # actually provide a --universal option.
  # The caller must have previously both arranged for the formula to have some sort of :universal option, artificially if necessary,
  # and called ARGV#force_universal_mode to ensure the appropriate environment variables are adjusted correctly.
  def force_universal_mode
    return if mode != :plain  # Either it’s already universal & we’ve finished, or it’s :bottle & we can’t in the first place.
    s_args.force_universal_mode  # Note that this call’s receiver is not ARGV, so it doesn’t affect the environment.
  end

  def effective_formula_flags; s_args.effective_formula_flags; end

  # @private
  def used_options; options & @o_args; end

  # @private
  def used_options__modeless; used_options - Options.create(%w[cross local native universal]); end

  # @private
  def unused_options; options - @o_args; end

  private

  def option_defined?(val); options.include? val; end
end # BuildOptions
