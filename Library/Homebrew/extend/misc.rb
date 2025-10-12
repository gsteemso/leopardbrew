class Array
  def choke; self unless flatten.compact.empty?; end

  def list
    case length
      when 0 then ''
      when 1 then self[0].to_s
      when 2 then "#{self[0].to_s} and #{self[1].to_s}"
      else "#{self[0..-2] * ', '}, and #{self[-1].to_s}"
    end
  end # Array#list

  alias_method :includes?, :include? unless method_defined? :includes?
end # Array

module Enumerable
  alias_method :includes?, :include? unless method_defined? :includes?
end

class Hash
  alias_method :includes?, :include? unless method_defined? :includes?
end

class Module
  def attr_rw(*attrs)
    file, line, = caller.first.split(":")
    line = line.to_i
    attrs.each do |attr|
      module_eval <<-EOS, file, line
        def #{attr}(val=nil)
          val.nil? ? @#{attr} : @#{attr} = val
        end
      EOS
    end # each |attr|
  end # attr_rw
end # Module

class Numeric
  def nope; self unless self == 0; end  # return self, but nil when zero
end

class Object
  alias_method :responds_to?, :respond_to? unless method_defined? :responds_to?
end
