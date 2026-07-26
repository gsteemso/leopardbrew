require 'ostruct'

# This file contains a set of monkeypatches to backport modern Ruby features into Tiger’s ancient 1.8.2.

# Dir.glob accepts an array for its first argument in newer rubies,
# in which case it returns the results for all patterns as a single array.
class Dir
  class << self
    alias :oldglob :glob
    def glob(args, flags=0, &block)
      unless args.is_a?(Array)
        return oldglob(args, flags, &block)
      end
      args.map {|p| oldglob(p, flags, &block)}.flatten
    end # Dir::glob()
  end # class << self
end # class Dir

module Enumerable; def one?(&block); return map.size == 1 unless block; select(&block).size == 1; end; end

# Used in ExternalPatch#owner= in patch.rb.  Definition taken from Ruby 2.0; hopefully is compatible with 1.8.2.
class ERB
  module Util
    def url_encode(s); s.to_s.gsub(/[^a-zA-Z0-9_\-.]/n) { |m| sprintf("%%%02X", m.unpack("C")[0]) }; end
    alias u url_encode
    module_function :u
    module_function :url_encode
  end # module ERB::Util
end # class ERB

module Kernel; def Pathname(target); Pathname.new(target); end unless method_defined? :Pathname; end

class Object
  def instance_variable_defined?(ivar)
    raise NameError, "“#{ivar}” is not allowed as an instance variable name" unless ivar.to_s =~ /^@/
    instance_variables.include?(ivar.to_s)
  end
end # class Object

# OpenStruct in 1.8.2 uses eval to generate member getters/setters, which results in hilarious syntax errors if a member ends with
# an exclamation mark or a question mark. e.g.:
#   def #{name}=(x); @table[:#{name}] = x; end
# Becomes:
#   def all?=(x); @table[:all?] = x; end
# This notably breaks brew-deps.  1.8.6 et seq more sensibly use define_method.  This version is taken from 1.8.7.
class OpenStruct
  def modifiable
    raise(TypeError, "can't modify frozen #{self.class}", caller(2)) if self.frozen?
    @table
  end # OpenStruct#modifiable
  protected :modifiable

  def new_ostruct_member(name)
    name = name.to_sym
    unless self.respond_to?(name)
      class << self; self; end.class_eval do
        define_method(name) { @table[name] }
        define_method("#{name}=") { |x| modifiable[name] = x }
      end
    end
    name
  end # OpenStruct#new_ostruct_member()
end # class OpenStruct
