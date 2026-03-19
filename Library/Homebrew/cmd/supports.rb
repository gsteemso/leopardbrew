#:  Usage:  brew supports (--feature=/feature/ || --lang=/revision/)
#:
#:Example:
#:
#:    brew supports --lang=c11 --lang=c++14 --feature=tls
#:reports on whether the current build environment supports the 2011 revision of
#:the C language or the 2014 revision of the C++ language, as well as whether it
#:supports Thread-Local Storage.
#:
#:Using the “--cc=” option, you can specify a different compiler to test whether
#:it would change anything.

module Homebrew
  def supports
    valid_flag_seen = expecting_a_tag = false
    short = long = tag = nil
    ENV.universal_binary if ARGV.build_universal?
    cc = presentify ENV.compiler
    cc_v = ENV.compiler_version
    ARGV.each do |arg|
      orig_arg = arg
      if expecting_a_tag then tag = arg
      elsif arg =~ %r{^--(feature|lang)(=[+0-9a-z]*)?$}
        valid_flag_seen = true
        short = ($1 == 'lang' ? 'language' : $1)
        long = (short == 'language' ? 'language revision' : short)
        if $2 then tag = $2.lchop; orig_arg = tag; else expecting_a_tag = true; end
      end
      if tag
        tag = tag.downcase.gsub('+', 'x').to_sym
        if ENV.validate_feature_tag(tag)
          ohai "The compiler #{cc} version #{cc_v} does #{ENV.send("supports_#{short}?", tag) \
                                                      ? 'indeed' \
                                                      : 'not'} support the #{long} “#{orig_arg}”."
        else opoo "“#{orig_arg}” is not something Leopardbrew recognizes."; end
        expecting_a_tag = false
        tag = nil
      end
    end # each |arg|
    odie 'You must specify at least one of “--feature=” or “--lang=”, with a valid parameter.' unless valid_flag_seen
  end # supports

  def presentify(compiler_name); compiler_name.to_s =~ %r{^gcc_4_([02])$} ? "gcc-4.#{$1}" : compiler_name; end
end # Homebrew
