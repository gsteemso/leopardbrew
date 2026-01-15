class BuildOptions
  attr_accessor :s_args, :options

  # Note that argument options not actually defined by the formula may be carried by a BuildOptions object.  This allows techniques
  # such as inserting --universal flags for a formula that always builds :universal and so does not define a :universal option.

  # @private
  def initialize(arg_options, defined_options)
    @o_args = arg_options
    @s_args = @o_args.map{ |o| o.to_s }.extend(HomebrewArgvExtension)
    @options = defined_options
  end

  def fix_deprecation(deprecated_option)
    old_val, new_val = deprecated_option.old, deprecated_option.current
    if i = s_args.index("--#{old_val}") then @o_args[i] = Option.new(new_val); s_args[i] = "--#{new_val}"; end
  end

  # True if a {Formula}’s being built with a specific option, that’s not necessarily named “with-*” or “without-*”.
  # @deprecated
  def include?(val); s_args.include?("--#{val}"); end
  alias_method :includes?, :include?

  # True if a {Formula} is being built with a specific option.
  #   args << '--i-want-spam' if build.with? 'spam'
  #   args << '--qt-gui' if build.with? 'qt' # '--with-qt' ==> build.with? 'qt'
  # If a formula presents a user with a choice, but the choice must be fulfilled:
  #   args << (build.with?('example2') ? '--with-example2' : '--with-example1')
  def with?(val)
    if (Dependency === val or Requirement === val) then name = val.option_name
    elsif Option === val then name = val.name
    else name = val.to_s; end
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

  # Like ARGV#build_mode, but validated against the actual options on offer.
  def mode
    if option_defined?('universal')
      bm = s_args.build_mode
      return bm if option_defined?(bm.to_s)
      return :cross if bm == :local and Target.local_archs == Target.cross_archs
    end
    bottle_or_plain
  end # mode

  # True if a {Formula} is being built as a universal binary, whether native‐only, locally‐oriented, or cross‐compiled.
  #   ENV.universal_binary if build.universal?
  def universal?; s_args.build_universal? and option_defined?('universal'); end
  alias_method :fat?, :universal?

  # True if a {Formula} is being built for multiple platforms.
  def cross?; universal? and mode == :cross; end

  # True if a {Formula} is being built for all local architectures.
  # e.g. on Intel under Snow Leopard this means a combined ppc/i386/x86_64 binary or library.
  def local?; universal? and mode == :local; end

  # True if a {Formula} is being built for native architectures only (those which can be run without emulation).
  # e.g. on Intel under Tiger through Snow Leopard this means a combined i386/x86_64 binary or library.
  def native?; universal? and mode == :native; end

  # What it says.  Must be kept in sync with the version in extend/ARGV.  For formulæ that always build universal, and as such have
  # never needed to provide a --universal option.
  def force_universal_mode
    universal_option_already_defined = option_defined?('universal')
    already_got_a_universal = includes?('universal')
    already_got_the_mode = includes?(mode.to_s)
    already_got_a_mode_eq = @o_args.include?('mode')
    s_args.force_universal_mode
    @options << Option.new('universal') unless universal_option_already_defined
    @o_args << 'universal' unless already_got_a_universal
    @o_args << mode.to_s unless already_got_the_mode
    @o_args << "mode=#{mode}" unless already_got_a_mode_eq
  end

  # True if a {Formula} is being built in 32-bit (i386 and/or ppc) mode.
  # This is needed for some use-cases though we prefer to define Universal builds wherever possible.
  def build_32_bit?; s_args.build_32_bit? and option_defined?('32-bit'); end

  # Like ARGV#effective_formula_flags, but validated against the actual options on offer.
  def effective_formula_flags
    efffl = s_args.effective_formula_flags - ["--#{s_args.build_mode}"]
    efffl << "--#{mode}" unless mode == :plain or mode == :bottle
    efffl
  end

  # @private
  def used_options; options & @o_args; end

  # @private
  def used_options__modeless; used_options - Options.create(%w[cross local native universal]); end

  # @private
  def unused_options; options - @o_args; end

  private

  def bottle_or_plain; bottle? ? :bottle : :plain; end

  def option_defined?(val); options.include? val; end
end # BuildOptions
