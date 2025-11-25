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
  alias_method :includes?, :include? unless method_defined? :includes?

  def intersects?(enum); enum.any?{ |e| includes? e }; end
  alias_method :intersect?, :intersects?

  def intersects_all?(*enums); enums.all?{ |enum| intersects? enum }; end
  alias_method :intersect_all?, :intersects_all?
end # Enumerable

class Hash; alias_method :includes?, :include? unless method_defined? :includes?; end

class Module
  def attr_rw(*attrs)
    file, line, = caller.first.split(":")
    attrs.each{ |attr| module_eval "def #{attr}(val=nil); val.nil? ? @#{attr} : @#{attr} = val; end", file, line.to_i }
  end # attr_rw
end # Module

class Numeric; def nope; self unless self == 0; end; end  # return self, but nil when zero

class Object; alias_method :responds_to?, :respond_to? unless method_defined? :responds_to?; end
