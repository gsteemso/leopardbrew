#:`brew uses foo bar` returns formulæ that use both foo and bar.
#:If you want the union, run the command twice and concatenate the results.  The
#:intersection is harder to achieve with shell tools.

require "formula"

module Homebrew
  def uses
    raise FormulaUnspecifiedError if ARGV.named.empty?

    used_formulae = ARGV.formulae
    formulae = (ARGV.include? "--installed") ? Formula.installed : Formula
    recursive = ARGV.flag? "--recursive"
    ignores = []
    ignores << "build?" if ARGV.include? "--skip-build"
    ignores << "optional?" if ARGV.include? "--skip-optional"

    uses = formulae.select do |f|
      used_formulae.all? do |ff|
        begin
          if recursive
            deps = f.recursive_dependencies do |dependent, dep|
              Dependency.prune if ignores.any?{ |ignore| dep.send(ignore) } and not dependent.build.with?(dep)
            end
            reqs = f.recursive_requirements do |dependent, req|
              Requirement.prune if ignores.any?{ |ignore| req.send(ignore) } and not dependent.build.with?(req)
            end
            deps.any?{ |dep| dep.to_formula.full_name == ff.full_name rescue dep.name == ff.name } or
              reqs.any?{ |req| req.name == ff.name or [ff.name, ff.full_name].include?(req.default_formula) } or
              (f.installed? and Keg.new(f.prefix).enhanced_by?(ff))
          else
            deps = f.deps.reject{ |dep| ignores.any?{ |ignore| dep.send(ignore) } }
            reqs = f.requirements.reject{ |req| ignores.any?{ |ignore| req.send(ignore) } }
            deps.any?{ |dep| dep.to_formula.full_name == ff.full_name rescue dep.name == ff.name } or
              reqs.any?{ |req| req.name == ff.name or [ff.name, ff.full_name].include?(req.default_formula) } or
              (f.installed? and Keg.new(f.prefix).enhanced_by?(ff))
          end
        rescue FormulaUnavailableError
          # Silently ignore this case, as we don't care about things used in taps that aren't currently tapped.
        end
      end
    end

    puts_columns uses.map(&:full_name)
  end
end
