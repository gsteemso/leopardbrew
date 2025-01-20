class BuildOptions
  attr_accessor :s_args

  # @private
  def initialize(arg_options, defined_options)
    @o_args = arg_options
    @s_args = @o_args.map { |o| o.to_s }.extend(HomebrewArgvExtension)
    @defined_options = defined_options
  end

  def fix_deprecation(deprecated_option)
    old_name, new_name = deprecated_option.old, deprecated_option.current
    if include? old_name
      @o_args -= [Option.new(old_name)]
      s_args -= ["--#{old_name}"]
      @o_args << Option.new(new_name)
      s_args << "--#{new_name}"
    end
  end

  # True if a {Formula} is being built with a specific option
  # (which isn't named `with-*` or `without-*`).
  # @deprecated
  def include?(name)
    s_args.include?("--#{name}")
  end

  # True if a {Formula} is being built with a specific option.
  # <pre>args << '--i-want-spam' if build.with? 'spam'
  #
  # args << '--qt-gui' if build.with? 'qt' # '--with-qt' ==> build.with? 'qt'
  #
  # # If a formula presents a user with a choice, but the choice must be fulfilled:
  # if build.with? 'example2'
  #   args << '--with-example2'
  # else
  #   args << '--with-example1'
  # end</pre>
  def with?(val)
    name = val.respond_to?(:name) ? val.name : val  # if we’re being asked about an Option rather
                                                    # than about a string, use its name
    if option_defined? "with-#{name}"
      include? "with-#{name}"
    elsif option_defined? "without-#{name}"
      !include? "without-#{name}"
    else
      false
    end
  end

  # True if a {Formula} is being built without a specific option.
  # <pre>args << '--no-spam-plz' if build.without? 'spam'
  def without?(name)
    !with? name
  end

  # True if a {Formula} is being built as a bottle (i.e. binary package).
  def bottle?
    s_args.build_bottle?
  end

  # True if a {Formula} is being built with {Formula.head} instead of {Formula.stable}.
  # <pre>args << '--some-new-stuff' if build.head?</pre>
  # <pre># If there are multiple conditional arguments use a block instead of lines.
  #  if build.head?
  #    args << '--i-want-pizza'
  #    args << '--and-a-cold-beer' if build.with? 'cold-beer'
  #  end</pre>
  def head?
    s_args.build_head?
  end

  # True if a {Formula} is being built with {Formula.devel} instead of {Formula.stable}.
  # <pre>args << '--some-beta' if build.devel?</pre>
  def devel?
    s_args.build_devel?
  end

  # True if a {Formula} is being built with {Formula.stable} instead of {Formula.devel} or {Formula.head}. This is the default.
  # <pre>args << '--some-beta' if build.devel?</pre>
  def stable?
    s_args.build_stable?
  end

  # True if a {Formula} is being built universally.
  # e.g. on newer Intel Macs this means a combined x86_64/x86 binary/library.
  # <pre>args << '--universal-binary' if build.universal?</pre>
  def universal?
    s_args.build_universal? && option_defined?('universal')
  end

  # True if a {Formula} is being built for multiple platforms.
  def cross?; s_args.build_cross? and option_defined?('cross'); end

  # True if a {Formula} is being built in C++11 mode.
  def cxx11?
    include?('c++11') && option_defined?('c++11')
  end

  # True if a {Formula} is being built in 32-bit/x86 mode.
  # This is needed for some use-cases though we prefer to build Universal
  # when a 32-bit version is needed.
  def build_32_bit?
    s_args.build_32_bit? && option_defined?('32-bit')
  end

  # @private
  def used_options
    @defined_options & @o_args
  end

  # @private
  def unused_options
    @defined_options - @o_args
  end

  private

  def option_defined?(name)
    @defined_options.include? name
  end
end
