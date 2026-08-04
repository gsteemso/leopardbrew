require "formula"
require "tab"

module Homebrew
  def missing_deps(ff)
    missing = {}
    ff.each do |f|
      missing_deps = f.recursive_dependencies do |dependent, dep|
        if dep.discretionary? then Dependency.prune unless Tab.for_formula(dependent).with?(dep)
        elsif dep.build? then Dependency.prune; end
      end
      missing_deps = missing_deps.map(&:to_formula).reject{ |f| f.any_version_installed? }
      unless missing_deps.empty?
        yield f.full_name, missing_deps if block_given?
        missing[f.full_name] = missing_deps
      end
    end # each |f|
    missing
  end # missing_deps()

  def missing
    return unless HOMEBREW_CELLAR.exists?
    ff = ARGV.named.empty? ? Formula.installed : ARGV.resolved_formulae
    missing_deps(ff) do |name, missing|
      print "#{name}: " if ff.size > 1
      puts "#{missing * " "}"
    end
  end # missing
end # Homebrew
