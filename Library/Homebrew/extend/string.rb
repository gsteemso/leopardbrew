class String
  def undent
    gsub(/^[ \t]{#{(slice(/^[ \t]+/) || '').length}}/, "")
  end

  # eg:
  #   if foo then <<-EOS.undent_________________________________________________________72
  #               Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do
  #               eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
  #               minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip
  #               ex ea commodo consequat. Duis aute irure dolor in reprehenderit in
  #               voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur
  #               sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt
  #               mollit anim id est laborum.
  #               EOS
  alias_method :undent_________________________________________________________72, :undent

  # String.chomp, but if result is empty: returns nil instead.
  # Allows `choke || foo` short-circuits.
  def choke; s = chomp; s unless s.empty?; end

  # Similar, but for number strings.  If the string does not represent a
  # number, or otherwise evaluates to zero, return nil.
  def nope; n = to_i; n unless n == 0; end

  # String#chop, but for the front of the string instead of the back.
  def pre_chop; self[1..-1]; end

  # String#chomp, but for the front of the string instead of the back.
  def pre_chomp(kill_this = "\n"); (self[0] == kill_this.to_s[0]) ? pre_chop : self; end

  alias_method :includes?,    :include?    unless method_defined? :includes?
  alias_method :starts_with?, :start_with? unless method_defined? :starts_with?
  alias_method :ends_with?,   :end_with?   unless method_defined? :ends_with?
end # String

class NilClass
  def choke; end
  def nope; end
end

# used by the inreplace function (in utils.rb)
module StringInreplaceExtension
  attr_accessor :errors

  def self.extended(str); str.errors = []; end

  def sub!(before, after)
    result = super
    unless result
      errors << "expected replacement of #{before.inspect} with #{after.inspect}"
    end
    result
  end # StringInreplaceExtension#sub!

  # Warn if nothing was replaced
  def gsub!(before, after, audit_result = true)
    result = super(before, after)
    if audit_result && result.nil?
      errors << "expected replacement of #{before.inspect} with #{after.inspect}"
    end
    result
  end # StringInreplaceExtension#gsub!

  # Looks for Makefile style variable defintions and replaces the
  # value with "new_value", or removes the definition entirely.
  def change_make_var!(flag, new_value)
    unless gsub!(/^#{Regexp.escape(flag)}[ \t]*=[ \t]*(.*)$/, "#{flag}=#{new_value}", false)
      errors << "expected to change #{flag.inspect} to #{new_value.inspect}"
    end
  end

  # Removes variable assignments completely.
  def remove_make_var!(flags)
    Array(flags).each do |flag|
      # Also remove trailing \n, if present.
      unless gsub!(/^#{Regexp.escape(flag)}[ \t]*=.*$\n?/, "", false)
        errors << "expected to remove #{flag.inspect}"
      end
    end
  end # StringInreplaceExtension#remove_make_var!

  # Finds the specified variable
  def get_make_var(flag); self[/^#{Regexp.escape(flag)}[ \t]*=[ \t]*(.*)$/, 1]; end
end # StringInreplaceExtension
