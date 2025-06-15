require "migrator"
require "formula/renames"

module Homebrew
  def migrate
    raise FormulaUnspecifiedError if ARGV.named.empty?

    (fae = ARGV.resolved_formulae).each do |f|
      if f.oldname
        unless (rack = HOMEBREW_CELLAR/f.oldname).exists? and not rack.subdirs.empty?
          raise NoSuchRackError, f.oldname
        end
        raise "#{rack} is a symlink" if rack.symlink?
      end

      migrator = Migrator.new(f)
      migrator.migrate

      if FORMULA_SUBSUMPTIONS and (subsumptions = FORMULA_SUBSUMPTIONS[f.name])
        subsumptions.each do |old|
          if (rack = HOMEBREW_CELLAR/old).exists? \
              # don’t delete new stuff that might be using a subsumed name:
              and not Formulary.from_rack(rack).installed?
            raise "#{rack} is a symlink" if rack.symlink?
            # TODO:  this will fail if the subsumed formula was insinuated.  (None are yet.)
            rack.rmtree
          end # is the subsumed formula still installed?
        end # each |old| formula subsumed by f
      end # did f subsume anything?
    end # each resolved formula |f|
  end # migrate
end # Homebrew
