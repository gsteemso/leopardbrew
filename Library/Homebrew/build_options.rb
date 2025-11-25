class BuildOptions
  attr_accessor :s_args, :options

  # @private
  def initialize(arg_options, defined_options)
    @o_args = arg_options
    @s_args = @o_args.map{ |o| o.to_s }.extend(HomebrewArgvExtension)
    @options = defined_options
  end

  def fix_deprecation(deprecated_option)
    old_val, new_val = deprecated_option.old, deprecated_option.current
    if includes? old_val
      @o_args -= [Option.new(old_val)]
      s_args -= ["--#{old_val}"]
      @o_args << Option.new(new_val)
      s_args << "--#{new_val}"
    end
  end # fix_deprecation

  # True if a {Formula}’s being built with a specific option, that’s not necessarily named “with-*”
  # or “without-*”.
  # @deprecated
  def include?(val); s_args.include?("--#{val}"); end
  alias_method :includes?, :include?

  # True if a {Formula} is being built with a specific option.
  # args << '--i-want-spam' if build.with? 'spam'
  # args << '--qt-gui' if build.with? 'qt' # '--with-qt' ==> build.with? 'qt'
  # # If a formula presents a user with a choice, but the choice must be fulfilled:
  # if build.with? 'example2' then args << '--with-example2'
  # else args << '--with-example1'
  # end
  def with?(val)
    if (Dependency === val or Requirement === val) then name = val.option_name
    elsif Option === val then name = val.name
    else name = val.to_s; end
    if option_defined?("with-#{name}") then includes?("with-#{name}")
    elsif option_defined?("without-#{name}") then ! includes?("without-#{name}")
    else false; end
  end # with?

  # True if a {Formula} is being built without a specific option.
  # args << '--no-spam-plz' if build.without? 'spam'
  def without?(val); !with? val; end

  # True if a {Formula} is being built as a bottle (i.e. binary package).
  def bottle?; s_args.build_bottle?; end

  # True if a {Formula} is being built with {#head} instead of {#stable}.
  # args << '--some-new-stuff' if build.head?
  # # If there are multiple conditional arguments, use a block.
  #  if build.head?
  #    args << '--i-want-pizza'
  #    args << '--and-a-cold-beer' if build.with? 'cold-beer'
  #  end
  def head?; s_args.build_head?; end

  # True if a {Formula} is being built with {#devel} instead of {#stable}.
  # args << '--some-beta' if build.devel?
  def devel?; s_args.build_devel?; end

  # True if a {Formula} is being built with {#stable}, not {#devel} or {#head}.  This is the default.
  # args << '--some-beta' if build.devel?
  def stable?; s_args.build_stable?; end

  # True if a {Formula} is being built as a universal binary, whether locally‐oriented or cross‐compiled.
  # ENV.universal_binary if build.universal?
  def universal?; s_args.build_universal? and option_defined?('universal'); end

  # True if a {Formula} is being built for multiple platforms.
  def cross?; universal? and s_args.build_mode == :cross; end

  # True if a {Formula} is being built for multiple local architectures.
  # e.g. on Power Macs this means a combined ppc/ppc64 binary or library.
  def local_fat?; universal? and s_args.build_mode == :local; end

  # True if a {Formula} is being built in C++11 mode.
  def cxx11?; include?('c++11') and option_defined?('c++11'); end

  # True if a {Formula} is being built in 32-bit (i386 and/or ppc) mode.
  # This is needed for some use-cases though we prefer to define Universal builds wherever possible.
  def build_32_bit?; s_args.build_32_bit? and option_defined?('32-bit'); end

  # @private
  def used_options; options & @o_args; end

  # @private
  def unused_options; options - @o_args; end

  private

  def option_defined?(val); options.include? val; end
end # BuildOptions
