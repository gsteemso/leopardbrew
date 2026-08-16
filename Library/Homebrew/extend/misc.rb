class Array
  def choke; self unless flatten.compact.empty?; end

  def list(connective = 'and')
    _self = map{ |item| item.is_a?(Symbol) ? item.inspect : item.to_s }
    case length
      when 0 then ''
      when 1 then _self[0]
      when 2 then "#{_self[0]} #{connective} #{_self[1]}"
      else "#{_self[0..-2] * ', '}, #{connective} #{_self[-1]}"
    end
  end # Array#list()

  alias_method :includes?, :include? unless method_defined? :includes?
end # Array

module Enumerable
  def find_rindex(val = nil)
    raise ArgumentError, 'Enumerable#find_rindex() must be given exactly one of a value or a block' unless block_given? ^ val
    n = length
    reverse_each{ |item|
      n = n - 1
      if (block_given? ? yield(item) : item == val) then return n; end
    }
    nil
  end # Enumerable#find_rindex()

  def includes_all?(*enum); enum.all?{ |e| includes? e }; end
  alias_method :include_all?, :includes_all?

  alias_method :includes?, :include? unless method_defined? :includes?

  def intersects?(enum); enum.any?{ |e| includes? e }; end
  alias_method :intersect?, :intersects?

  def intersects_all?(*enums); enums.all?{ |enum| intersects? enum }; end
  alias_method :intersect_all?, :intersects_all?
end # Enumerable

class Hash
  def any?(&block); each_pair{ |k, v| if yield(k, v) then return true; end }; false; end unless method_defined? :any?

  def delete_at(key, &block); h = {}; Array(key).each{ |k| h[k] = delete(k, &block) }; h; end unless method_defined? :delete_at

  alias_method :includes?, :include? unless method_defined? :includes?
end # Hash

class Integer; def byteswap4; (self < 0 or self > 0xFFFFFFFF) ? self : [self].pack('N').unpack('V').first; end; end

class Module
  # Defines a single, combined reader/writer method for each <attr>.  If called with an argument, provided that the argument is not
  # {nil}, the method assigns @<attr> that value.  It finishes by returning the value of @<attr>, which is unchanged if no argument
  # (or a {nil} one) was passed.
  def attr_rw(*attrs)
    file, line, _ = caller.first.split(':')
    attrs.each{ |attr| module_eval "def #{attr}(val=nil); val.nil? ? @#{attr} : @#{attr} = val; end", file, line.to_i }
  end

  # Similar to #attr_accessor, but the reader methods’ names each have a question mark appended and only return {true} or {false}.
  def mode_attr_accessor(*attrs)
    file, line, _ = caller.first.split(':')
    attrs.each{ |a| module_eval "def #{a}=(val); @#{a} = val; end; def #{a}?; !!@#{a}; end", file, line.to_i }
  end

  # Each entry in name_hash relates to one instance variable.  The key is its name‐symbol; the value is an array of its permissible
  # states, of which the the first is assigned as the initial value.  (Valid state values are {false}, {nil}, {true}, {Symbol}s, or
  # anything which does not produce an empty string when interpolated.)  After the initial value is assigned, accessors are defined
  # for assignment, for reading the raw state, and for querying each individual state.  For example, an entry of
  #     {:tristate => [:high_Z, :low, :high]}
  # would yield the methods #tristate, #tristate=(), #tristate_high_Z?, #tristate_low?, and #tristate_high?.  Lastly, if any of the
  # permitted states are {nil} and/or {false}, an additional query method is generated:  #<var_name>?.  This only returns {true} or
  # {false}, in the same manner as a mode_attr_accessor.
  def n_state_attr(name_hash)
    file, line, _ = caller.first.split(':')
    name_hash.each_pair do |name, states|
      as_str = states.map{ |state| case state
                                     when false  then 'false'
                                     when nil    then 'nil'
                                     when true   then 'true'
                                     when Symbol then ":#{state}"
                                                 else "'#{state}'"
                                   end }
      code_block = [
          "@#{name} = #{as_str[0]}",
          "def #{name}; @#{name}; end",
          "def #{name}=(new_state)",
          "  raise(RuntimeError, \"Invalid state “\#{new_state}” assigned to #{name}\", caller) \\",
          "    unless [#{as_str * ', '}].include?(new_state)",
          "  @#{name} = new_state",
          'end',
        ]
      code_block << "def #{name}?; !!@#{name}; end" if states.intersect? [false, nil]
      states.each_with_index{ |state, i| code_block << "def #{name}_#{state}?; @#{name} && @#{name} == #{as_str[i]}; end" }
      module_eval(code_block * "\n", file, line.to_i)
    end # each entry in the name hash
  end # Module#n_state_attr()
end # Module

class Numeric; def nope; self unless self == 0; end; end  # return self, but nil when zero

class Object
  alias_method :are_a?,       :is_a?       unless method_defined? :are_a?
  alias_method :are_an?,      :is_a?       unless method_defined? :are_an?
  alias_method :is_an?,       :is_a?       unless method_defined? :is_an?
  alias_method :responds_to?, :respond_to? unless method_defined? :responds_to?
end # class Object

class Set; alias_method :includes?, :include? unless method_defined? :includes?; end

class Time
  # The standard JSON methods for Time objects do not appear to be present in Ruby 1.8.6 or earlier.  Strangely, we still can’t use
  # them with the internal Ruby 2.3.3 we inherited from Tigerbrew, because Time#as_json seems to be missing (a detail we shall have
  # to address when we finally get around to updating that).  Until then, this very basic JSON serialization suits our low‐end JSON
  # reader/writer.
  require 'utils/json'

  def self.from_JSON(json_string); from_JSONable(Utils::JSON.load json_string); end

  def self.from_JSONable(object); object.is_a?(Hash) ? at(object['s'], object['mu']) : at(object); end

  def to_JSON; Utils::JSON.dump(to_JSONable); end

  def to_JSONable; {'s' => tv_sec, 'mu' => tv_usec}; end
end # Time
