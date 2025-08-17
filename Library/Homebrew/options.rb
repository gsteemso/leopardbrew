require 'set'

OPTION_RX = %r{^--([^=]+=?)(.+)?$}

class Option
  attr_reader :name, :description, :flag
  attr_accessor :value

  def initialize(name, description = '')
    @name = name
    @flag = "--#{name}"
    @description = description
    @value = ''
  end

  def to_s; value && value != '' ? "#{flag}=#{value}" : flag; end

  def <=>(o); return unless Option === o; (name == o.name) ? value <=> o.value : name <=> o.name; end

  def ==(o); instance_of?(o.class) and name == o.name and value = o.value; end
  alias_method :eql?, :==

  def hash; name.hash; end

  def inspect; "#<#{self.class.name}:  #{to_s}>"; end
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

  def self.create(array)
    creation = new array.map{ |e| Option === e ? e : Option.new(e[OPTION_RX, 1] || e) }
    creation.each do |o|
      candidate = array.to_a.reverse.find{ |e| not Option === e and e.to_s.starts_with? o.flag }
      if candidate =~ OPTION_RX and $2 then o.value = $2; end
    end
    creation
  end # Options⸬create

  def initialize(*args); @options = Set.new(*args); end

  def each(*args, &block); @options.each(*args, &block); end

  def <<(o); @options << o; self; end

  def -(o); self.class.create(@options - o); end

  def &(o); self.class.create(@options & o); end

  def |(o); self.class.create(@options | o); end
  alias_method :+, :|

  def *(arg); @options.to_a.map(&:to_s) * arg; end

  def empty?; @options.empty?; end

  def as_flags; map(&:to_s); end

  def include?(other)
    other_name = case other.class.to_s
        when 'String'   then (other.starts_with?('--') ? (other =~ OPTION_RX)[1] : other[/^[^=]+/])
        when 'Option'   then other.name
        when 'NilClass' then ''
        else raise RuntimeError, "Options object queried re inclusion of alien class “#{other.class}”"
      end
    any?{ |o| o.name == other_name }
  end # include?

  alias_method :to_ary, :to_a

  def inspect; "#<#{self.class.name}: #{to_a.inspect}>"; end

  def list; to_a.list; end
end # Options
