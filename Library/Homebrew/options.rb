require 'set'

OPTION_RX = %r{^(?:--)?([^=]+=?)(.+)?$}

# Note that settable Options have a name and flag that end with an equals sign.  This is intentional.  To get one bare (without its
# equals sign), just use String#chomp('=').
class Option
  attr_reader :name, :description, :flag
  attr_accessor :value

  def initialize(nm, desc = '')
    @description = desc
    if Option === nm
      @name, @value = nm.name, nm.value
    else nm.to_s =~ OPTION_RX
      @name, @value = ($1 || ''), ($2 || '')
    end
    raise RuntimeError, 'nameless Option somehow created!' if @name == ''
    @flag = "--#{@name}"
  end

  def to_s; value.choke ? "#{flag}#{value}" : flag; end

  def <=>(o); return unless Option === o; (name <=> o.name).nope || value <=> o.value; end

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

  def self.create(opts); new Array(opts).map{ |o| Option === o ? o : Option.new(o) }; end

  def initialize(*args); @options = Set.new(*args); end

  def each(*args, &block); @options.each(*args, &block); end

  def <<(o); @options << o; self; end

  def -(o); self.class.create(@options - Array(o)); end

  def &(o); self.class.create(@options & Array(o)); end

  def |(o); self.class.create(@options | Array(o)); end
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
