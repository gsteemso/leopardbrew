require "migrator"
require "formula/renames"

module Homebrew
  def migrate
    raise FormulaUnspecifiedError if ARGV.named.empty?

    ARGV.resolved_formulae.each do |f|
      if f.oldname
        unless (rack = HOMEBREW_CELLAR/f.oldname).exists? and not rack.subdirs.empty?
          raise NoSuchRackError, f.oldname
        end
        raise "#{rack} is a symlink" if rack.symlink?
      end

      migrator = Migrator.new(f)
      migrator.migrate

      if (subsumptions = FORMULA_SUBSUMPTIONS.fetch(f.name, nil))
        subsumptions.each do |old|
          if (rack = HOMEBREW_CELLAR/old).exists? \
              and not Formulary.from_rack(rack).installed?  # don’t delete new stuff with a subsumed name
            raise "#{rack} is a symlink" if rack.symlink?
            # TODO:  this will fail if the subsumed formula was insinuated.  (None are yet.)
            rack.rmtree
          end # is the subsumed formula still installed?
        end # each |old| formula subsumed by f
      end # did f subsume anything?
    end # each resolved formula |f|
  end # migrate
end # Homebrew
