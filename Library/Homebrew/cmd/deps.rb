#:  Usage:  brew deps --tree [/SKIP/] [--all | --installed | /formula/ [...]]
#:          brew deps [/1/] [/SKIP/] (--all | --installed)
#:          brew deps [/1/] [/SKIP/] [--installed] [--union] /formula/ [...]
#:
#:          …where /1/ stands for [--1 | --recursive], and /SKIP/ stands for
#:                     ([--skip-build] [--skip-discretionary | --skip-optional]).
#:
#:This command lists all dependencies of the specified formulæ.  Display options
#:are a tree view or a sorted list of dependency names.  Listing can skip any or
#:all of these dependency types:  Optional, discretionary (optional/recommended),
#:build-only, or recursive [list view only].  List view for named /formulæ/ also
#:may show the union instead of the intersection of the lists generated for each
#:one.  (“Intersection” is the default as it’s harder to get using other tools.)

# encoding: UTF-8
require 'formula'
require 'ostruct'

module Homebrew

  # necessary for 1.8.7 unicode handling
  TICK   = "#{TTY.green}#{["2714".hex].pack("U*")}#{TTY.reset}".freeze
  CROSS  = "#{TTY.red}#{["2718".hex].pack("U*")}#{TTY.reset}".freeze

  def deps
    raise ArgvSyntaxError, 'The --1 and --tree options are mutually exclusive' if mode.tree? and not mode.recursive?
    raise FormulaUnspecifiedError if ARGV.named.empty? and not (mode.all? or mode.installed?)
    if mode.tree?
      category_label = mode.no_discr? ? 'required' : mode.no_optnl? ? 'recommended' : 'all'
      category_label += ' run-time' if mode.no_build?
      puts_deps_tree((mode.installed? ? Formula.installed : mode.all? ? Formula : ARGV.formulae), category_label)
    elsif mode.all? or mode.installed?
      puts_deps(mode.all? ? Formula : Formula.installed)
    else
      all_deps = deps_for_formulae(ARGV.formulae, &(mode.union? ? :| : :&))
      all_deps = all_deps.select(&:installed?) if mode.installed?
      puts all_deps.map(&:name).uniq.sort
    end
  end # deps

  def mode
    @a ||= ARGV.includes? '--all'
    @i ||= ARGV.includes? '--installed'
    @mode ||= OpenStruct.new(
        :all?       => @a && (!@i || @a > @i),
        :installed? => @i && (!@a || @i > @a),
        :recursive? => ARGV.recursion != :no,
        :tree?      => ARGV.includes?('--tree'),
        :union?     => ARGV.includes?('--union')
      )
  end # mode

  def gather_ignores
    { 'build?'         => ARGV.includes?('--skip-build'),
      'optional?'      => ARGV.includes?('--skip-optional') && !ARGV.includes?('--skip-discretionary'),
      'discretionary?' => ARGV.includes?('--skip-discretionary'),
    }
  end # gather_ignores

  def gather_deps_and_reqs(formula, ignores = gather_ignores)
    if mode.recursive?
      deps = formula.recursive_dependencies do |dependent, dependency|
          Dependency.prune \
            if ignores.any?{ |ignore, act| act and dependency.send(ignore) } and not dependent.build.with?(dependency)
        end
      reqs = formula.recursive_requirements do |dependent, requirement|
          Requirement.prune \
            if ignores.any?{ |ignore, act| act and requirement.send(ignore) } and not dependent.build.with?(requirement)
        end
    else
      deps = formula.deps.reject{ |dependency| ignores.any?{ |ignore, act| act and dependency.send(ignore) } }
      reqs = formula.requirements.reject{ |requirement| ignores.any?{ |ignore, act| act and requirement.send(ignore) } }
    end
    [deps, reqs]
  end # gather_deps_and_reqs()

  def deps_for_formula(f)
    deps, reqs = gather_deps_and_reqs(f)
    (deps + reqs.select(&:default_formula?).map(&:to_dependency)).uniq
  end

  def deps_for_formulae(formulae, &block); formulae.map{ |f| deps_for_formula f }.inject(&block); end

  def puts_deps(formulae)
    formulae.each{ |f|; d = deps_for_formula f; puts "#{f.full_name}:  #{d.sort_by(&:name).list}" if d and not d.empty? }
  end

  def puts_deps_tree(formulae, category_label)
    formulae.each do |f|
      puts "#{f.full_name} (#{category_label} dependencies)"
      recursive_deps_tree(f, '', gather_ignores)
      puts
    end
  end # puts_deps_tree

  def recursive_deps_tree(f, prefix, ignores, dependency_chain = [f.name])
    reqs = f.requirements.select(&:default_formula?).reject{ |dep| ignores.any?{ |ignore, act| act and dep.send(ignore) } }.sort
    deps = f.deps.reject{ |dep| ignores.any?{ |ignore, act| act and dep.send(ignore) } }.sort
    dmax = deps.length - 1
    max = reqs.length + dmax
    reqs.map(&:to_dependency).each_with_index do |dep, i|
      nm = dep.name
      raise "{#{nm}} has a circular dependency!\n    {#{dependency_chain * '} → {'}} → {#{nm}}" if dependency_chain.includes? nm
      ff = dep.to_formula
      str = i == max ? '└──' : '├──'
      prefix_ext = i == max ? '    ' : '│   '
      puts prefix + "#{str} :#{nm}#{" #{ff.installed? ? TICK : CROSS}" unless NO_EMOJI}"
      recursive_deps_tree(ff, prefix + prefix_ext, ignores, dependency_chain + [nm])
    end
    deps.each_with_index do |dep, i|
      nm = dep.name
      raise "{#{nm}} has a circular dependency!\n    {#{dependency_chain * '} → {'}} → {#{nm}}" if dependency_chain.includes? nm
      ff = dep.to_formula
      str = i == dmax ? '└──' : '├──'
      prefix_ext = i == dmax ? '    ' : '│   '
      puts prefix + "#{str} #{nm}#{" #{ff.installed? ? TICK : CROSS}" unless NO_EMOJI}"
      recursive_deps_tree(ff, prefix + prefix_ext, ignores, dependency_chain + [nm])
    end
  end # recursive_deps_tree()
end # Homebrew
