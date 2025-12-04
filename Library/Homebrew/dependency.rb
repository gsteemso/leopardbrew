require "dependable"

# A dependency on another Homebrew formula.
class Dependency
  include Dependable

  attr_reader :name, :tags, :env_proc, :option_name

  DEFAULT_ENV_PROC = proc {}

  def initialize(name, tags = [], env_proc = DEFAULT_ENV_PROC, option_name = name)
    odie "Dependency created with a Symbol for a name:  “#{name.inspect}”" if name.is_a? Symbol
    @name = name
    @tags = tags
    @env_proc = env_proc
    @option_name = option_name || name
  end # initialize

  def to_s; name; end

  def ==(other); instance_of?(other.class) && name == other.name && tags == other.tags; end
  alias_method :eql?, :==

  def <=>(other)
    return nil unless other.is_a?(Dependency)  # This allows direct comparison of different derived classes.
    name <=> other.name
  end

  def hash; name.hash ^ tags.hash; end

  def to_formula
    formula = Formulary.factory(name)  # Can’t use `Formula[]`, it produces `nil` instead of a {Formula} subclass.
    formula.build = BuildOptions.new(Options.create(formula.installed? ? Tab.for_formula(formula).used_options \
                                                                       : ARGV.effective_formula_flags), formula.options)
    formula
  end

  def installed?; to_formula.installed?; end

  def satisfied?(inherited_options)
    installed? && missing_options(inherited_options).empty?
  end

  def missing_options(inherited_options)
    required = options | inherited_options
    required - Tab.for_formula(to_formula).used_options
  end

  def modify_build_environment; env_proc.call unless env_proc.nil?; end

  def inspect; "#<#{self.class.name}:  #{name.inspect} #{tags.inspect}>"; end

  # Define marshaling semantics because we cannot serialize @env_proc
  def _dump(*); Marshal.dump([name, tags]); end

  def self._load(marshaled); new(*Marshal.load(marshaled)); end

  class << self
    # Expand the dependencies of dependent recursively, optionally yielding [dependent, dep] pairs
    # to allow callers to apply arbitrary filters to the list.
    # The default filter, which is applied when a block is not given, omits optionals and
    # recommendeds based on what the dependent has asked for.
    def expand(dependent, deps = dependent.deps, original_dependent = dependent, &block)
      expanded_deps = []
      deps.each do |dep|
        raise "The formula #{dep.name} depends on itself!" if dep.name == dependent.name
        raise "The formula #{dependent.name} circularly depends on #{original_dependent.name}!" \
                                                                                             if dep.name == original_dependent.name
        next if expanded_deps.include? dep
        f = dep.to_formula
        case action(dependent, dep, &block)
          when :prune then next
          when :skip  then expanded_deps.concat(expand(f, f.deps, original_dependent, &block))
          when :keep_but_prune_recursive_deps then expanded_deps << dep
          else
            expanded_deps.concat(expand(f, f.deps, original_dependent, &block))
            expanded_deps << dep
        end
      end # each |dep|
      merge_repeats(expanded_deps)
    end # Dependency⸬expand

    def action(dependent, dep, &_block)
      catch(:action) do
        if block_given? then yield dependent, dep
        elsif dep.optional? or dep.recommended?
          prune unless dependent.build.with?(dep)
        end
      end
    end # Dependency⸬action

    # Prune a dependency and its dependencies recursively
    def prune; throw(:action, :prune); end

    # Prune a single dependency but do not prune its dependencies
    def skip; throw(:action, :skip); end

    # Keep a dependency, but prune its dependencies
    def keep_but_prune_recursive_deps; throw(:action, :keep_but_prune_recursive_deps); end

    def merge_repeats(all)
      grouped = all.group_by(&:name)
      all.map(&:name).uniq.map do |name|
        deps = grouped.fetch(name)
        dep  = deps.first
        tags = deps.flat_map(&:tags).uniq
        dep.class.new(name, tags, dep.env_proc)
      end # all |name|s
    end # Dependency⸬merge_repeats
  end # << self
end # Dependency

class TapDependency < Dependency
  attr_reader :tap

  def initialize(name, tags = [], env_proc = DEFAULT_ENV_PROC, option_name = name.split("/").last)
    @tap = name.rpartition("/").first
    super(name, tags, env_proc, option_name)
  end

  def installed?
    super
  rescue FormulaUnavailableError
    false
  end
end # TapDependency
