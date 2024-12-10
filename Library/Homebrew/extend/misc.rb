class Array
  alias_method :includes?, :include? unless method_defined? :includes?
end

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
