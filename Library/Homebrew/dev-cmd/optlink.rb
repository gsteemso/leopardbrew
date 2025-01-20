#:
#:Regenerate the “opt” link for a brewed formula.
#:
#:  Usage:    brew optlink /formula/ [...]
#:
#:Brewed formulæ rely on a symbolic link in $HOMEBREW_PREFIX/opt/(formula name).
#:If this link is broken or missing, a brewed formula is useless. `brew optlink`
#:guarantees the correctness of each given formula’s link by regenerating it.
#:
#:By default (i.e., without a versioned formula name or --stable/--devel/--HEAD
#:flags), it tries to preserve the currently‐active version (selected via `brew
#:switch`).  When a formula ends with “@(version)”, it switches to that version.
#:Otherwise, it switches to the installed current version selected by the usual
#:flags – or if no flags are passed and no current version is installed, to the
#:least out‐of‐date installed version.
#:

require 'keg'

module Homebrew
  def optlink
    raise KegUnspecifiedError if ARGV.named.empty?
    ARGV.kegs.each do |keg|
      raise NoSuchVersionError, keg.versioned_name unless keg.exists?
      optrec = keg.opt_record
      keg.optlink
    end # each ARGV |keg|
  end # optlink
end # module Homebrew
