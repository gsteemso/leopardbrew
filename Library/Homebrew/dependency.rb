require "dependable"

# A dependency on another Homebrew formula.
class Dependency
  include Dependable  # includes attr_readers for :name & :tags, and methods .options & .unreserved_tags

  attr_accessor :option_name
  protected('option_name=')
  attr_reader :env_proc

  def initialize(name, tags = [], option_name = nil, &env_proc)
    odie "Dependency created with a Symbol for a name:  “#{name.inspect}”" if name.is_a? Symbol
    @name = name
    @tags = Set[*tags]
    @option_name = option_name || name
    @env_proc = Proc.new if block_given?
  end # Dependency#initialize

  def ==(other)
    instance_of?(other.class) and
      name == other.name and
      tags == other.tags and
      option_name == other.option_name
  end # Dependency#==
  alias_method :eql?, :==

  def <=>(other); return nil unless other.is_a? Dependency; name <=> other.name; end
  # “unless other.is_a? Dependency” allows direct comparison of different derived classes.


# Commands:

  def modify_build_environment; env_proc.call if env_proc; end


# Predicates:

  def installed?; to_formula.installed?; end

  def installed_archs_are_a_superset?
    keg = Keg.for(to_formula.prefix)
    keg and Target.archset.all?{ |ta| keg.built_archs.any?{ |ba| ba == ta } }
  end

  def is_group_dep?; false; end

  def satisfied?; installed? and missing_options.empty? and installed_archs_are_a_superset?; end


# Methods returning internal data:

  def hash; name.hash ^ self.class.to_s.hash ^ tags.hash; end

  def inspect
    "#{self.class.to_s}:  #{name} (tags #{tags.inspect};#{" option #{option_name};" if option_name != name} env_proc #{env_proc.inspect})"
  end

  def to_s; name; end


# Methods returning external data:

  def missing_options; options - Tab.for_formula(to_formula).used_options; end

  def to_formula
    @formula ||= begin
                   f = Formulary.factory(name)  # Can’t use `Formula[]`, it produces `nil` instead of a {Formula} subclass.
                   f.build = BuildOptions.new(Options.create(options), f.options)  # Note:  These build options are those specified
                   f                                                               #        by tags, NOT as installed or via ARGV.
                 end
  end # Dependency#to_formula


# Define marshaling semantics, because we cannot serialize @env_proc:

  def _dump(*); Marshal.dump([name, tags, option_name]); end

  def self._load(marshaled); new(*Marshal.load(marshaled)); end

  class << self
    # Expand the dependencies of dependent recursively, optionally yielding [dependent, dep] pairs so callers might apply arbitrary
    # filters to the list.  The default filter, applied when a block is not given, omits optionals and recommendeds per which build
    # options the dependent is depended upon with – which are not always the formula defaults.
    # dependent is a {Formula}‐subclass instance (FSI).  deps is a {Dependencies} object.  dependency_chain is an {Array} of FSIs.
    def expand(dependent, deps = dependent.deps, dependency_chain = [dependent], &block)
      expanded_deps = Dependencies.new
      deps.each do |dep|
        next if expanded_deps.include? dep
        if dep.is_a? GroupDependency; deps += dep.subdeps; next; end  # unpack, but otherwise ignore, group dependencies
        f = dep.to_formula
        raise "{#{f.name}} has a circular dependency!\n    {#{dependency_chain * '} → {'}} → {#{f.name}}" \
                                                                                                    if dependency_chain.includes? f
        a = action(dependent, dep, &block) || :no_action
        next if a == :prune
        expanded_deps += expand(f, f.deps, dependency_chain + [f], &block) \
                                                                        unless a == :keep_but_prune_recursive_deps or f.deps.empty?
        expanded_deps << dep unless a == :skip
      end # each |dep|
      expanded_deps
    end # Dependency::expand

    # Keep a dependency, but prune its dependencies.
    def keep_but_prune_recursive_deps; throw(:action, :keep_but_prune_recursive_deps); end

    # Prune a dependency and its dependencies recursively.
    def prune; throw(:action, :prune); end

    # Prune a single dependency but do not prune its dependencies.
    def skip; throw(:action, :skip); end

    private

    def action(dependent, dep, &_block)
      catch(:action) do
        if block_given? then yield dependent, dep; elsif dep.discretionary? then prune unless dependent.build.with?(dep); end
      end
    end
  end # << self
end # Dependency

class GroupDependency < Dependency
  attr_reader :subdeps
  def initialize(name, tags, constituents, dep_collector, &env_proc)  # Note that any env proc passed only applies once, outermost.
    raise ArgumentError, 'Group-dependency tags may only include :build, :optional, :recommended, or :run.' \
      if tags.any?{ |tag| not RESERVED_TAGS.include? tag }
    super(name, tags, &env_proc)
    raise ArgumentError, "Dependency group “#{name}” MUST have :optional or :recommended priority" unless discretionary?
    @subdeps = Dependencies.new
    constituents.each do |subname|
      if subname.is_a? Hash then subtags = subname.values.first; subname = subname.keys.first; else subtags = []; end
      raise ArgumentError, 'Group-dependency member tags may not include :build, :optional, :recommended, or :run.' \
        if subtags.any?{ |subtag| RESERVED_TAGS.include? subtag }
      if subdep = dep_collector.add(subname => (tags + subtags)) and subdep.is_a? Dependency
        subdep.option_name = name; @subdeps << subdep; end
    end # each constituent |subname|
  end # GroupDependency#initialize

  def ==(other); super(other) and subdeps == other.subdeps; end

  def installed?; subdeps.all?(&:installed?); end

  def is_group_dep?; true; end

  def satisfied?; subdeps.all?{ |subdep| subdep.satisfied? }; end

  def inspect; "#{super} – sub‐dependencies <#{subdeps.inspect}>"; end

  def to_formula; false; end

  def missing_options(_); false; end
end # GroupDependency

class TapDependency < Dependency
  attr_reader :tap

  def initialize(name, tags = [], option_name = name.split('/').last, &env_proc)
    @tap = name.rpartition('/').first
    super(name, tags, option_name, &env_proc)
  end

  def installed?
    super
  rescue FormulaUnavailableError
    false
  end
end # TapDependency
