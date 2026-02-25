class Array
  def choke; self unless flatten.compact.empty?; end

  def list(connective = 'and')
    _self = map{ |item| Symbol === item ? item.inspect : item.to_s }
    case length
      when 0 then ''
      when 1 then _self[0]
      when 2 then "#{_self[0]} #{connective} #{_self[1]}"
      else "#{_self[0..-2] * ', '}, #{connective} #{_self[-1]}"
    end
  end # Array#list

  alias_method :includes?, :include? unless method_defined? :includes?
end # Array

module Enumerable
  def find_rindex(val = nil, &block); if n = reverse.find_index(val, &block) then length - n - 1; end; end

  alias_method :includes?, :include? unless method_defined? :includes?

  def intersects?(enum); enum.any?{ |e| includes? e }; end
  alias_method :intersect?, :intersects?

  def intersects_all?(*enums); enums.all?{ |enum| intersects? enum }; end
  alias_method :intersect_all?, :intersects_all?
end # Enumerable

class Hash; alias_method :includes?, :include? unless method_defined? :includes?; end

class Module
  def attr_rw(*attrs)
    file, line, _ = caller.first.split(":")
    attrs.each{ |attr| module_eval "def #{attr}(val=nil); val.nil? ? @#{attr} : @#{attr} = val; end", file, line.to_i }
  end

  def n_state_attr(name_hash)
    name_hash.each{ |name, states|
      strung_states = states.map{ |state| !state ? 'false' : state.is_a?(Symbol) ? ":#{state}" : "'#{state}'" }
      module_eval "@#{name} = #{strung_states[0]}"
      attr_reader(name)
      module_eval <<_
def #{name}=(new_state)
  raise "Invalid state “\#{new_state}” assigned to #{name}" unless [#{strung_states * ', '}].includes?(new_state)
  @#{name} = new_state
end
_
      states.each_with_index{ |state, i|
        if state then module_eval "def #{name}_#{state}?; @#{name} && @#{name} == #{strung_states[i]}; end"
        else module_eval "def #{name}?; !!@#{name}; end" unless method_defined? "#{name}?"; end
      }
    } # each entry in the name hash
  end # Module#n_state_attr()
end # Module

class Numeric; def nope; self unless self == 0; end; end  # return self, but nil when zero

class Object; alias_method :responds_to?, :respond_to? unless method_defined? :responds_to?; end
