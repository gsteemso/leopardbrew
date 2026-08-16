# This file contains backports of assorted things found in Rubies newer than Leopard’s 1.8.6.
# Items pertaining to the Pathname class are handled separately (QV).

require 'extend/tiger' if RUBY_VERSION == '1.8.2'

class Dir
  # This definition comes from Ruby 1.8.7.
  def Dir.mktmpdir(prefix_suffix=nil, tmpdir=nil)
    case prefix_suffix
      when nil    then prefix = "d";              suffix = ""
      when String then prefix = prefix_suffix;    suffix = ""
      when Array  then prefix = prefix_suffix[0]; suffix = prefix_suffix[1]
                  else raise ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
    end
    tmpdir ||= Dir.tmpdir
    t = Time.now.strftime("%Y%m%d"); n = nil
    begin
      path = "#{tmpdir}/#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
      path << "-#{n}" if n
      path << suffix
      Dir.mkdir(path, 0700)
    rescue Errno::EEXIST
      n ||= 0; n += 1; retry
    end
    if block_given? then begin yield path; ensure FileUtils.remove_entry_secure path; end
    else path; end
  end unless defined? Dir.mktmpdir
end # Dir

module Enumerable
  def flat_map
    return to_enum(:flat_map) unless block_given?
    r = []; each{ |*args| result = yield(*args); result.respond_to?(:to_ary) ? r.concat(result) : r.push(result) }
    r
  end unless method_defined?(:flat_map)

  def group_by; inject({}) { |h, e| h.fetch(yield(e)) { |k| h[k] = [] } << e; h }; end unless method_defined?(:group_by)
end # Enumerable

class Hash
  # Hashes are unordered in Ruby 1.8, but 1.8.7 nevertheless provides a #first method.  This is weird, but we use it in Leopardbrew
  # for single-length hashes.
  def first; each{ |el| break el }; end unless method_defined?(:first)
end

class Integer
  # These were defined by the time of Ruby 2.0, but did not exist in 1.8.x.
  def even?; self & 1 == 0; end unless method_defined? :even?
  def odd?; self & 1 != 0; end unless method_defined? :odd?
end

class String
  # String#starts_with? – note the “s” – is documented, but apparently not implemented, in Ruby 1.8.x.
  def start_with?(*prefixes)
    prefixes.any? do |prefix|
      if prefix.respond_to?(:to_s) then prefix = prefix.to_s; prefix.length > 0 and self[0, prefix.length] == prefix; end
    end # any |prefix|?
  end unless method_defined?(:start_with?)

  # This, on the other hand, was neither documented nor implemented in Ruby 1.8.x.
  def end_with?(*suffixes)
    suffixes.any? do |suffix|
      if suffix.respond_to?(:to_s); suffix = suffix.to_s; (suf_len = suffix.length) > 0 and self[-suf_len, suf_len] == suffix; end
    end # any |suffix|?
  end unless method_defined?(:end_with?)

  def rpartition(separator)
    (ind = rindex separator) ? [slice(0, ind), separator, slice(ind+1, -1) || ''] : ['', '', dup]
  end unless method_defined?(:rpartition)
end # String

class Symbol; def to_proc; proc { |*args| args.shift.send(self, *args) }; end unless method_defined?(:to_proc); end
