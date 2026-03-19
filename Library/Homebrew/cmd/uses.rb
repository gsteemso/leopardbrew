#:  Usage:  brew uses [--1 | --recursive] [--installed] [--skip-build]
#:          [--skip-discretionary | --skip-optional] [--union] /formula/ [...]
#:
#:This command lists all dependents, or all installed dependents, of the formulæ
#:specified.  List generation can be told to omit any or all of these dependency
#:types:  Optional, discretionary (i.e. optional OR recommended), build-only, or
#:recursive.  The list also may show the union, rather than the intersection, of
#:the sub‐lists generated from each /formula/.  (The intersection is computed by
#:default because that’s harder to generate using other tools.)

require 'cmd/deps'
require 'formula'

module Homebrew
  def uses
    raise FormulaUnspecifiedError if ARGV.named.empty?
    used_formulae = ARGV.formulae
    formulae = ARGV.includes?('--installed') ? Formula.installed : Formula
    recursive = ARGV.recursion == :yes
    uses = formulae.select do |f|
        used_formulae.all? do |ff|
          begin
            deps, reqs = gather_deps_and_reqs(f)
            reqs = reqs.select(&:default_formula?)
            deps.any?{ |dep| dep.to_formula.full_name == ff.full_name rescue dep.name == ff.name } or
              reqs.any?{ |req| req.name == ff.name or [ff.name, ff.full_name].include?(req.default_formula) } or
              (f.installed? and Keg.new(f.prefix).enhanced_by?(ff))
          rescue FormulaUnavailableError
            # Silently ignore this case, as we don't care about things used in taps that aren't currently tapped.
          end # “begin/rescue” block
        end # all? block:  used formulæ |ff|
      end # select block:  user formulæ |f|
    puts_columns uses.map(&:full_name)
  end # uses
end # Homebrew
