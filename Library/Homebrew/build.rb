# This script is loaded by formula/installer.rb as a separate instance.
# Thrown exceptions are propagated back to the parent process over a pipe.

old_trap = trap('INT') { exit! 130 }

require 'global'
require 'build_options'
require 'cxxstdlib'
require 'keg'
require 'extend/ENV'
require 'debrew'
require 'fcntl'

class Build
  attr_reader :formula, :deps, :reqs, :aids

  def initialize(f, args)
    @formula = f
    @formula.build = BuildOptions.new(Options.create(args), f.options)
    if ARGV.ignore_deps?
      @deps = []
      @reqs = []
    else
      @deps = expand_deps
      @reqs = expand_reqs
    end
    @aids = (ARGV.ignore_aids? ? [] : f.active_enhancements)
  end # initialize

  def post_superenv_hacks
    # Only allow Homebrew-approved directories into the PATH, unless
    # a formula opts-in to allowing the user's path.
    if formula.env.userpaths? or reqs.any? { |rq| rq.env.userpaths? }
      ENV.userpaths!
    end
  end # post_superenv_hacks

  def effective_build_options_for(dependent)
    opt_args  = dependent.build.used_options
    opt_args |= Tab.for_formula(dependent).used_options
    BuildOptions.new(opt_args, dependent.options)
  end

  def expand_reqs
    formula.recursive_requirements do |dependent, req|
      build = effective_build_options_for(dependent)
      if (req.optional? or req.recommended?) and build.without?(req)
        Requirement.prune
      elsif req.build? and dependent != formula
        Requirement.prune
      elsif req.satisfied? and req.default_formula? and (dep = req.to_dependency).installed?
        deps << dep
        Requirement.prune
      end
    end
  end # expand_reqs

  def expand_deps
    formula.recursive_dependencies do |dependent, dep|
      build = effective_build_options_for(dependent)
      if (dep.optional? or dep.recommended?) and build.without?(dep)
        Dependency.prune
      elsif dep.build?
        if dependent != formula
          Dependency.prune
        else
          Dependency.keep_but_prune_recursive_deps
        end
      end
    end
  end # expand_deps

  def install
    _deps = deps.map(&:to_formula) + aids
    keg_only_deps = _deps.select(&:keg_only?)
    _deps.each { |dep| fixopt(dep) unless dep.opt_prefix.directory? }

    ENV.activate_extensions!

    if superenv?
      ENV.keg_only_deps = keg_only_deps
      ENV.deps = _deps
      ENV.x11 = reqs.any? { |rq| rq.is_a?(X11Requirement) }
    end

    ENV.setup_build_environment(formula)

    post_superenv_hacks if superenv?

    reqs.each(&:modify_build_environment)
    deps.each(&:modify_build_environment)

    keg_only_deps.each do |dep|
      ENV.prepend_path 'PATH', dep.opt_bin.to_s
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{dep.opt_lib}/pkgconfig"
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{dep.opt_share}/pkgconfig"
      ENV.prepend_path 'ACLOCAL_PATH', "#{dep.opt_share}/aclocal"
      ENV.prepend_path 'CMAKE_PREFIX_PATH', dep.opt_prefix.to_s
      ENV.prepend 'LDFLAGS', "-L#{dep.opt_lib}" if dep.opt_lib.directory?
      ENV.prepend 'CPPFLAGS', "-I#{dep.opt_include}" if dep.opt_include.directory?
    end unless superenv?

    formula.extend(Debrew::Formula) if DEBUG

    formula.brew do
      formula.patch

      if ARGV.git?
        system 'git', 'init'
        system 'git', 'add', '-A'
      end

      formula.prefix.mkpath
      if ARGV.interactive?
        ohai 'Entering interactive mode'
        puts 'Type “exit” to return and finalize the installation'
        puts "Install to this prefix:  #{TTY.white}#{formula.prefix}#{TTY.reset}"

        if ARGV.git?
          puts 'This directory is now a git repo. Make your changes and then use:'
          puts '    git diff | pbcopy'
          puts 'to copy the diff to the clipboard.'
        end

        interactive_shell(formula)
      else
        formula.install
      end

      raise RuntimeError, 'Empty installation; aborting' if formula.prefix.children.empty?

      stdlibs = detect_stdlibs(ENV.compiler)
      Tab.create(formula, ENV.compiler, stdlibs.first, formula.build, get_archs).write

      # Find and link metafiles
      formula.prefix.install_metafiles Pathname.pwd
      formula.prefix.install_metafiles formula.libexec if formula.libexec.exists?
    end # of {formula}#brew block
  end # install

  def get_archs
    ENV.homebrew_built_archs or raise RuntimeError, '$HOMEBREW_BUILT_ARCHS is empty!  WTF did we just build?'
  end

  def detect_stdlibs(compiler)
    keg = Keg.new(formula.prefix)
    CxxStdlib.check_compatibility(formula, deps, keg, compiler)

    # The stdlib recorded in the install receipt is used during dependency
    # compatibility checks, so we only care about the stdlib that libraries
    # link against.
    keg.detect_cxx_stdlibs(:skip_executables => true)
  end # detect_stdlibs

  def fixopt(f)
    path = if f.linked_keg.directory? and f.linked_keg.symlink?
        f.linked_keg.resolved_path
      elsif f.prefix.directory?
        f.prefix
      elsif (gik = f.greatest_installed_keg)
        gik.path
      else
        raise RuntimeError, 'can’t make opt/ link:  none of the usual directories are valid'
      end
    Keg.new(path).optlink
  rescue StandardError
    raise "#{f.opt_prefix} is missing or broken.\nPlease reinstall #{f.full_name}."
  end # fixopt
end # Build

trap('INT') {
  if DEBUG then raise RuntimeError, 'User Interrupt'
  else old_trap; end
}

begin
  error_pipe = IO.new(ENV['HOMEBREW_ERROR_PIPE'].to_i, 'w')
  error_pipe.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

  formula = ARGV.formulae.first
  build   = Build.new(formula, ARGV.effective_flags)
  build.install
rescue Exception => e
  Marshal.dump(e, error_pipe) rescue nil
  error_pipe.close
  exit! 1
end
