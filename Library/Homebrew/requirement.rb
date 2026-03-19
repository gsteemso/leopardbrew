require 'build_environment'
require 'dependable'  # pulls in 'options' and 'set'
require 'dependencies'
require 'dependency'

# A base class for any non-{Formula} prerequisites of formulæ.  A “fatal” requirement fails the build if not satisfied.  By default,
# {Requirement}s are non-fatal.
class Requirement
  include Dependable  # includes attr_readers for :name & :tags, and methods .options & .unreserved_tags

  attr_reader :cask, :download
  alias_method :option_name, :name

  def initialize(tags = [])
    @cask ||= self.class.cask
    @download ||= self.class.download
    (tags = Array(tags).to_set).each do |tag|
      next unless tag.is_a? Hash
      @cask ||= tag[:cask]
      @download ||= tag[:download]
    end
    @tags = Set[*tags]
    @name ||= infer_name
  end # Requirement#initialize

  def ==(other); instance_of?(other.class) && name == other.name && tags == other.tags; end
  alias_method :eql?, :==

  def default_formula; self.class.default_formula; end
  alias_method :default_formula?, :default_formula

  def env; self.class.env; end

  def env_proc; self.class.env_proc; end

  # Overriding #fatal? is deprecated.  Pass a boolean to the ::fatal DSL method instead.
  def fatal?; self.class.fatal; end

  def hash; name.hash ^ tags.hash; end

  def inspect; "#<#{self.class.name}: #{name.inspect} #{tags.inspect}>"; end

  # The message to show when the requirement is not met.
  def message
    s = ''
#   s +=  <<-EOS.undent if cask
#     You can install with Homebrew Cask:
#         brew install Caskroom/cask/#{cask}
#   EOS
    s += <<-EOS.undent if download
      You can download from:
          #{download}
    EOS
    s
  end # Requirement#message

  # Overriding #modify_build_environment is deprecated; pass a block to the ::env DSL method instead.  Note:  #satisfied? should be
  # called before invoking this method, as the environment modifications may depend on its side effects.
  def modify_build_environment
    instance_eval(&env_proc) if env_proc
    # If the satisfy block returns a {Pathname}, make sure it remains available on the $PATH.  This makes requirements like
    #     satisfy { which('executable') }
    # work, even under Superenv where “executable” isn’t necessarily on the $PATH.
    if Pathname === @satisfied_result
      parent = @satisfied_result.parent
      unless ENV['PATH'].split(File::PATH_SEPARATOR).includes?(parent.to_s)
        ENV.append_path('PATH', parent)
      end
    end
  end # Requirement#modify_build_environment

  # Overriding #satisfied? is deprecated.  Pass a block or boolean to the ::satisfy DSL method instead.
  def satisfied?
    result = self.class.satisfy.yielder{ |p| instance_eval(&p) }
    @satisfied_result = result
    !!result
  end

  def to_dependency
    f = self.class.default_formula || raise("No default formula defined for #{inspect}")
    args = [f, tags, option_name]
    (HOMEBREW_TAP_FORMULA_REGEX === f) ? TapDependency.new(*args) { modify_build_environment } \
                                       : Dependency.new(*args) { modify_build_environment }
  end

  private

  def infer_name
    klass = self.class.name || self.class.to_s
    klass.sub!(/(Dependency|Requirement)$/, '')
    klass.sub!(/^(\w+::)*/, '')
    klass.downcase
  end # Requirement#infer_name

  def which(cmd); super(cmd, ORIGINAL_PATHS.join(File::PATH_SEPARATOR)); end

  class Satisfier
    def initialize(options, &block)
      case options
        when Hash
          @options = { :build_env => true }
          @options.merge!(options)
        else
          @satisfied = options
      end
      @proc = block
    end # Satisfier#initialize

    def yielder
      if instance_variable_defined?(:@satisfied)
        @satisfied
      elsif @options[:build_env]
        require 'extend/ENV'
        ENV.activate_extensions!
        ENV.with_build_environment { yield @proc }
      else
        yield @proc
      end
    end # Satisfier#yielder
  end # Satisfier

  class << self
    include BuildEnvironmentDSL

    attr_reader :env_proc
    attr_rw :cask, :default_formula, :download, :fatal

    def satisfy(options = {}, &block); @satisfied ||= Requirement::Satisfier.new(options, &block); end

    def env(*settings, &block); if block_given? then @env_proc = block; else super; end; end

    # Expand the requirements of “dependent” recursively, optionally yielding [dependent, req] pairs so callers may apply arbitrary
    # filters to the list.  The default filter, applied when no block is given, omits optionals and recommendeds based on the given
    # options.
    # “dependent” is a {Formula}‐subclass instance.
    def expand(dependent, &block)
      reqs = Requirements.new
      formulae = dependent.recursive_dependencies.map(&:to_formula)
      formulae.unshift(dependent)
      formulae.each{ |f| f.requirements.each{ |req| if prune?(f, req, &block) then next; else reqs << req; end } }
      reqs
    end # Requirement::expand

    # Used to prune requirements when calling expand with a block.
    def prune; throw(:prune, true); end

    # “dependent” is a Formula‐subclass instance.
    # “req” is a {Requirement}.
    def prune?(dependent, req, &block)
      catch(:prune) do
        if block_given? then yield dependent, req
        elsif req.discretionary? and dependent.build.without?(req) then prune; end
      end
    end # Requirement::prune?
  end # Requirement << self
end # Requirement
