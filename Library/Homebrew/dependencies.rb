class Dependencies
  include Enumerable

  alias_method :to_ary, :to_a

  attr_reader :deps
  protected :deps

  def initialize(initial_deps = []); @deps = initial_deps; end

  def +(other); @deps += other.deps if other.is_a? Dependencies; uniq; end

  def *(arg); @deps.sort * arg; end

  def ==(other); deps == other.deps; end
  alias_method :eql?, :==

  def <<(other); @deps << other unless not other.is_a?(Dependency) or other.is_group_dep? or @deps.include?(other); self; end

  def each(*args, &block); @deps.each(*args, &block); end

  def empty?; @deps.empty?; end

  def inspect; "#<#{self.class.name}:  #{to_a.inspect}>"; end

  def list; @deps.list; end

  def uniq; @deps = deps.uniq; self; end


  def build; select(&:build?); end

  def build_optional; select(&:build_optional?); end

  def build_recommended; select(&:build_recommended?); end

  def build_required; select(&:build_required?); end

  def default; build - build_optional + required + recommended; end

  def optional; select(&:optional?); end

  def recommended; select(&:recommended?); end

  def required; select(&:required?); end

  def run_optional; select(&:run_optional?); end

  def run_recommended; select(&:run_recommended?); end
end # Dependencies

class Requirements
  include Enumerable

  alias_method :to_ary, :to_a

  def initialize; @reqs = Set.new; end

  def <<(other)
    @reqs.grep(other.class) do |req|
      return self if Comparable === other and req > other
      @reqs.delete(req)
    end
    @reqs << other
    self
  end # Requirements#<<

  def each(*args, &block); @reqs.each(*args, &block); end

  def to_dependencies; Dependencies.new(select(&:default_formula?).map(&:to_dependency)); end
end # Requirements
