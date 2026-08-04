#:  Usage:  brew uncheckpoint [options] [<formula> [...]]
#:
#:Available options:
#:  --mode=<...>    Removes only checkpoints for builds under the indicated mode.
#:  --with-<...>, --without-<...>
#:                  Removes only checkpoints using the specified option(s).
#:
#:Removes all applicable checkpoints for the named <formulæ> – or all applicable
#:checkpoints for every formula, if none are specified.

module Homebrew
  def uncheckpoint
    def uncheckroot(fname = false)
      pn, msg_fragment = fname ? [CHECKPOINTS/fname, "#{fname} has"] : [CHECKPOINTS, 'There are']
      if not pn.directory? or pn.empty? then puts "#{msg_fragment} no checkpoints to remove."
      else pn.each_child{ |ch|
        (flags_in_name = ch.basename.to_s.split('_')).shift                          # Drop the leading package‐version string.
        build_mode = flags_in_name.pop if ARGV.valid_build_mode?(flags_in_name[-1])  # Harvest any trailing build‐mode string.
        next if build_mode and (argv_mode = ARGV.value 'mode') and argv_mode.to_sym != build_mode
        with_without = ARGV.flags_only.select{ |flag| flag.to_s.starts_with?('--with') }
        next if not with_without.empty? and with_without.map{ |ww| ww.xlchop(2) }.any?{ |ww| not flags_in_name.include?(ww) }
        ch.rmtree
      }; pn.rmdir_if_possible; end
    end

    if ARGV.named.empty? then uncheckroot; else ARGV.formulae.each{ |f| uncheckroot f.name }; end
  end # uncheckpoint
end # Homebrew
