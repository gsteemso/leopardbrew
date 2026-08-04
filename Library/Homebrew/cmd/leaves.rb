require 'formula'
require 'tab'
require 'set'

module Homebrew
  def leaves
    installed = Formula.installed
    deps_of_installed = Set.new

    installed.each do |f|
      deps = []
      tab = Tab.for_formula(f)
      f.deps.each{ |dep| deps << dep.to_formula.full_name if not dep.discretionary? or tab.with?(dep) }
      deps_of_installed.merge(deps)
    end # each |f|

    installed.each do |f|
      puts f.full_name unless deps_of_installed.include? f.full_name
    end
  end # leaves
end # Homebrew
