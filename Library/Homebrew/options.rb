require 'set'

class Option
  attr_reader :name, :description, :flag

  def initialize(name, description = '')
    @name = name
    @flag = "--#{name}"
    @description = description
  end

  def to_s; flag; end

  def <=>(o); return unless Option === o; name <=> o.name; end

  def ==(o); instance_of?(o.class) and name == o.name; end
  alias_method :eql?, :==

  def hash; name.hash; end

  def inspect; "#<#{self.class.name}: #{flag.inspect}>"; end
end # Option

class DeprecatedOption
  attr_reader :old, :current

  def initialize(old, current)
    @old = old
    @current = current
  end

  def old_flag; "--#{old}"; end

  def current_flag; "--#{current}"; end

  def ==(o); instance_of?(o.class) and old == o.old and current == o.current; end
  alias_method :eql?, :==
end # DeprecatedOption

class Options
  include Enumerable

  def self.create(array); new array.map{ |e| Option.new(e[/^--([^=]+=?)(.+)?$/, 1] || e) }; end

  def initialize(*args); @options = Set.new(*args); end

  def each(*args, &block); @options.each(*args, &block); end

  def <<(o); @options << o; self; end

  def -(o); self.class.new(@options - o); end

  def &(o); self.class.new(@options & o); end

  def |(o); self.class.new(@options | o); end
  alias_method :+, :|

  def *(arg); @options.to_a * arg; end

  def empty?; @options.empty?; end

  def as_flags; map(&:flag); end

  def include?(other); any?{ |o| [o, o.name, o.flag].any?{ |opt| opt == other } }; end

  alias_method :to_ary, :to_a

  def inspect; "#<#{self.class.name}: #{to_a.inspect}>"; end
end # Options
