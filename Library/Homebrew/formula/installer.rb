require "cxxstdlib"
require "exceptions"
require "formula"
require "keg"
require "tab"
require "bottles"
require "caveats"
require "cleaner"
require "formula/cellar_checks"
require "install_renamed"
require "cmd/tap"
require "cmd/postinstall"
require "hooks/bottles"
require "debrew"
require "sandbox"
require "requirements/cctools_requirement"

class FormulaInstaller
  include FormulaCellarChecks

  # “*names” is a list of {Symbol}s.
  def self.mode_attr_accessor(*names)
    attr_accessor(*names)
    private(*names)
    names.each do |name|
      predicate = "#{name}?"
      define_method(predicate) { !!send(name) }
      private(predicate)
    end
  end # FormulaInstaller⸬mode_attr_accessor()

  attr_reader :formula
  mode_attr_accessor :build_bottle, :debug, :git, :ignore_aids, :interactive, :show_install_heading, :show_summary_heading
  n_state_attr :deps_do       => [false, :ignore, :only],    # was ignore_deps / only_deps
               :force         => [false, :source, :bottle],  # was build_from_source / force_bottle
               :poured_bottle => [false, :done, :fail],      # was poured_bottle / pour_failed
               :verbosity     => [false, :full, :less]       # was verbose / quieter

  # “formula” is a {Formula}‐subclass instance.
  def initialize(formula)
    @formula = formula

    # These are expected to be overridden individually by the caller.
    @build_bottle = false
    @debug = false
    @git = false
    @ignore_aids = false
    @interactive = false
    # The n-state variables @deps_do, @force, and @verbosity are already set to false.

    # These are state flags that are manipulated below as installation progresses.
    @show_install_heading = false
    @show_summary_heading = false
    # The n-state variable @pour_bottle is already set to false.

    @@attempted ||= Set.new
  end # initialize

  def options; formula.build.used_options; end

  def options=(opts); formula.build = BuildOptions.new(opts, formula.options); end

  def skip_deps_check?; deps_do_ignore?; end

  # When no build tools are available but build flags appear in ARGV, the user must be interrupted before a doomed installation can
  # be attempted.  Only invoked when the user has no developer tools.
  def self.prevent_build_flags
    build_flags = ARGV.collect_build_flags
    raise BuildFlagsError.new(build_flags) unless build_flags.empty?
  end

  # “install_bottle_options” is a {Hash} with only one possible key, “:warn”, with a Boolean value.
  def pour_bottle?(install_bottle_options = { :warn => false })
    return false if poured_bottle_fail?
    return true if Homebrew::Hooks::Bottles.formula_has_bottle?(formula)
    bottle = formula.bottle
    return true  if force_bottle? and bottle
    return false if force_source? or build_bottle? or interactive?
    return false unless options.empty?
    return true  if formula.local_bottle_path
    return false unless bottle && formula.pour_bottle?
    unless bottle.compatible_cellar?
      opoo "Building source; cellar of #{formula.full_name}’s bottle is #{bottle.cellar}" if install_bottle_options[:warn]
      return false
    end
    true
  end # pour_bottle?

  # “dep” is a depended-upon {Formula}‐subclass instance.
  # “build” is a {BuildOptions} instance.
  def install_bottle_for?(dep, build)
    return pour_bottle? if dep == formula
    !force_source? && dep.bottle && dep.pour_bottle? && build.used_options.empty? && dep.bottle.compatible_cellar?
  end

  def prelude; verify_deps_exist unless skip_deps_check?; lock; check_install_sanity; end

  def verify_deps_exist
    begin
      formula.recursive_dependencies.map(&:to_formula)
    rescue TapFormulaUnavailableError => e
      if Homebrew.install_tap(e.user, e.repo) then retry
      else raise; end
    end
  rescue FormulaUnavailableError => e
    e.dependent = formula.full_name
    raise
  end # verify_deps_exist

  def check_install_sanity
    raise FormulaInstallationAlreadyAttemptedError, formula if @@attempted.include?(formula)
    unless skip_deps_check?
      unlinked_deps = formula.recursive_dependencies.map(&:to_formula).select do |dep|
        dep.installed? and not dep.keg_only? and not dep.linked_keg.directory?
      end
      raise CannotInstallFormulaError,
        "You must `brew link #{unlinked_deps * ' '}` before #{formula.full_name} can be installed" unless unlinked_deps.empty?
    end # checking dependencies
  end # check_install_sanity

  def build_bottle_preinstall
    @etc_var_glob ||= "#{HOMEBREW_PREFIX}/{etc,var}/**/*"
    @etc_var_preinstall = Dir[@etc_var_glob]
  end

  def build_bottle_postinstall
    @etc_var_postinstall = Dir[@etc_var_glob]
    (@etc_var_postinstall - @etc_var_preinstall).each do |file|
      Pathname.new(file).cp_path_sub(HOMEBREW_PREFIX, formula.bottle_prefix)
    end
  end # build_bottle_postinstall

  def install
    # This test (“Is some version already installed and linked?”) is here instead of in #initialize so that various commands do not
    # need to unlink the active keg until immediately before calling this method, rather than needing to do so before instantiating
    # this class at all.  This cuts the odds of having to re‐link it – a noticeably slow operation.
    raise CannotInstallFormulaError, <<-EOS.undent if formula.linked_keg.directory?
        #{formula.name} #{formula.linked_keg.resolved_path.basename} is already installed.
        To install this version, first “brew unlink #{formula.name}”.
      EOS
    raise BuildToolsError.new([formula]) unless pour_bottle? or MacOS.has_apple_developer_tools?
    check_conflicts
    unless skip_deps_check?
      deps = compute_dependencies
      check_dependencies_bottled(deps) if pour_bottle? and not MacOS.has_apple_developer_tools?
      install_dependencies(deps)
    end
    return if deps_do_only?
    raise "Invalid target for --bottle-arch:  #{ARGV.bottle_arch}" if build_bottle? and not bottle_arch_is_valid?
    formula.deprecated_args.each do |deprecated_option|
      old_flag = deprecated_option.old_flag
      new_flag = deprecated_option.current_flag
      opoo "#{formula.full_name}:  #{old_flag} was deprecated; using #{new_flag} instead"
    end
    oh1 "Installing #{TTY.green}#{formula.full_name}#{TTY.reset}" if show_install_heading?
    @@attempted << formula
    if pour_bottle?(:warn => true)
      begin
        install_relocation_tools unless formula.bottle_specification.skip_relocation?
        pour
      rescue Exception => e
        # Any exceptions must leave us with nothing new installed.
        ignore_interrupts do
          formula.prefix.rmtree if formula.prefix.directory?
          formula.rack.rmdir_if_possible
        end
        poured_bottle = :fail
        if DEBUG
          onoe e.message, e.backtrace
        else
          onoe e.message
        end
        opoo "Bottle installation failed:  Building from source."
        raise BuildToolsError.new([formula]) unless MacOS.has_apple_developer_tools?
      else
        poured_bottle = :done
      end
    end # if pouring bottle
    build_bottle_preinstall if build_bottle?
    # Build from source:
    unless poured_bottle_done?
      install_dependencies(compute_dependencies) if poured_bottle_fail? and not skip_deps_check?
      build
      clean
    end
    build_bottle_postinstall if build_bottle?
    ofail "#{formula.full_name} was not successfully installed to #{formula.prefix}" unless formula.installed?
  end # install

  def check_conflicts
    return if ARGV.force?
    conflicts = formula.conflicts.select do |c|
        begin
          f = Formulary.factory(c.name)
        rescue TapFormulaUnavailableError
          # If the formula name is fully qualified, silently ignore it as we don’t care about things from taps not currently tapped.
          false
        else f.linked_keg.exist? and f.opt_prefix.exist?
        end
      end # do select |c|
    raise FormulaConflictError.new(formula, conflicts) unless conflicts.empty?
  end # check_conflicts

  # Compute and collect the dependencies needed by the formula currently being installed.
  def compute_dependencies
    req_map, req_deps = expand_requirements
    check_requirements(req_map)
    deps = expand_dependencies(req_deps + formula.deps)
  end # compute_dependencies

  # Check that each dependency in “deps” has a bottle available, terminating abnormally with a BuildToolsError if one or more don’t.
  # Only invoked when the user has no developer tools.
  # “deps” is a {Hash}, wherein each key is a {Dependency}.  We don’t care about the values.
  def check_dependencies_bottled(deps)
    unbottled = deps.reject{ |dep, _| dep.to_formula.pour_bottle? }
    raise BuildToolsError.new(unbottled) unless unbottled.empty?
  end

  # “req_map” is a Hash, where each key is a Formula‐subclass instance and each value is an Array of Requirement instances.
  def check_requirements(req_map)
    (fatals = req_map.dup).each_pair{ |dependent, reqs|
      reqs.each{ |req|
        unless req.fatal?
          fatals[dependent].delete(req)
          fatals.delete(dependent) if fatals[dependent] == []
        end
    } }
    raise UnsatisfiedRequirements.new(fatals) unless fatals.empty?
  end # check_requirements

  # “req” is a {Requirement} instance.
  # “dependent” is a {Formula}‐subclass instance.
  # “build” is a {BuildOptions} instance.
  # Returns a Boolean value.
  def install_requirement_default_formula?(req, dependent, build)
    return false unless req.default_formula?
    return true unless req.satisfied?
    return false if req.tags.include?(:run)
    install_bottle_for?(dependent, build) or build_bottle?
  end # install_requirement_default_formula

  # Returns a two‐element Array.  The first element is a Hash whose keys are Formula‐subclass instances and values are Requirement
  # instances.  The other element is an Array of Dependency instances.
  def expand_requirements
    unsatisfied_reqs = Hash.new { |h, k| h[k] = [] }
    deps = []
    formulae = [formula]
    while f = formulae.pop
      f.recursive_requirements do |dependent, req|
        build = effective_build_options_for(dependent)
        if (req.optional? or req.recommended?) and build.without?(req)
          Requirement.prune
        elsif req.build? and install_bottle_for?(dependent, build)
          Requirement.prune
        elsif install_requirement_default_formula?(req, dependent, build)
          dep = req.to_dependency
          deps.unshift(dep)
          formulae.unshift(dep.to_formula)
          Requirement.prune
        elsif req.satisfied?
          Requirement.prune
        else
          unsatisfied_reqs[dependent] << req
        end
      end # recursive requirements |dependent|, |req|
    end # pop formula f
    [unsatisfied_reqs, deps]
  end # expand_requirements

  # “deps” is a {Dependencies} instance.
  def expand_dependencies(deps)
    inherited_options = {}
    expanded_deps = Dependency.expand(formula, deps) do |dependent, dep|
        opts = inherited_options[dep.name] = inherited_options_for(dep)
        build = effective_build_options_for(dependent, inherited_options.fetch(dependent.name, []))
        if (dep.optional? or dep.recommended?) and build.without?(dep)
          Dependency.prune
        elsif dep.build? and install_bottle_for?(dependent, build)
          Dependency.prune
        elsif dep.satisfied?(opts)
          Dependency.skip
        end
      end # do expand |dependent, dep|
    expanded_deps.map { |dep| [dep, inherited_options[dep.name]] }
  end # expand_dependencies

  # “dependent” is a {Formula}‐subclass instance.
  # “inherited_options” is an optional {Options} instance.
  def effective_build_options_for(dependent, inherited_options = [])
    opt_args  = dependent.build.used_options
    opt_args |= dependent == formula ? options : inherited_options
    opt_args |= Tab.for_formula(dependent, :active).used_options  # Prefer an active keg over the most current.

    BuildOptions.new(opt_args, dependent.options)
  end # effective_build_options_for

  # “dep” is a {Dependency} instance.
  def inherited_options_for(dep)
    inherited_opts = Options.new
    f = dep.to_formula
    u = Option.new('universal')
    inherited_opts << u if not dep.build? and f.build.universal? and \
                                                        (options.include?(u) or ARGV.build_fat? or formula.require_universal_deps?)
    inherited_opts
  end # inherited_options_for

  # “deps” is a {Hash} whose keys are {Dependency} instances and values are {Options} instances, which might contain a “--universal”
  # {Option}.
  def install_dependencies(deps)
    if deps.empty? and deps_do_only?
      puts "All dependencies for #{formula.full_name} are satisfied."
    else
      oh1 "Installing dependencies for #{formula.full_name}: #{TTY.green}#{deps.map(&:first)*", "}#{TTY.reset}" unless deps.empty?
      deps.each{ |dep, opts| install_dependency(dep, opts) }
    end
    @show_install_heading = true unless deps.empty?
  end # install_dependencies

  # Installs the relocation tools (as provided by the cctools formula) as a hard dependency for any formula installed from a bottle
  # when the user has no developer tools.  Invoked unless the formula explicitly sets :any_skip_relocation in its bottle DSL.
  def install_relocation_tools
    return if MacOS.version >= :ventura  # cctools stopped being supported somewhere around here.
    cctools = CctoolsRequirement.new
    dependency = cctools.to_dependency
    formula = dependency.to_formula
    return if cctools.satisfied? or @@attempted.include?(formula)
    install_dependency(dependency, inherited_options_for(cctools))
  end # install_relocation_tools

  class DependencyInstaller < FormulaInstaller; def skip_deps_check?; true; end; end

  def install_dependency(dep, inherited_options)
    df = dep.to_formula
    tab = Tab.for_formula(df, :active)  # Not necessarily a current version.
    # Correctly unlink things even if a different version is linked:
    previously_linked = nil
    if df.linked_keg.directory?
      previously_linked = Keg.new(df.linked_keg.resolved_path)
      previously_linked.unlink
    end
    previously_installed = nil
    if df.installed?(tss = tab.spec)
      previously_installed = Keg.new(df.spec_prefix(tss))
      ignore_interrupts { previously_installed.rename }
    end
    di = DependencyInstaller.new(df)
    di.options           |= tab.used_options
    di.options           |= Tab.remap_deprecated_options(df.deprecated_options, dep.options)
    di.options           |= inherited_options
    di.force              = force_source? ? :source : false
    di.verbosity          = verbosity_full? ? :full : false
    di.prelude
    oh1 "Installing #{formula.full_name} dependency: #{TTY.green}#{dep.name}#{TTY.reset}"
    di.install
    di.finish  # this links the new keg
  rescue Exception
    # leave no trace of the failed installation
    if df.prefix.exists?
      oh1 "Cleaning up failed #{df.prefix}" if DEBUG
      ignore_interrupts { df.prefix.rmtree; df.rack.rmdir_if_possible }
    end
    ignore_interrupts { previously_installed.rename } if previously_installed
    previously_linked.link if previously_linked
    raise
  else
    if df.insinuation_defined?
      # Uninsinuate silently immediately before insinuation (do not emit conflicting messages).
      df.uninsinuate(DEBUG.nil?) rescue nil if previously_installed
      df.insinuate rescue nil
    end
  ensure
    Target.no_universal_binary
  end # install_dependency

  def caveats
    return if deps_do_only?

    audit_installed if DEVELOPER and not formula.keg_only?

    c = Caveats.new(formula)

    unless c.empty?
      @show_summary_heading = true
      ohai "Caveats", c.caveats
    end
  end # caveats

  def finish
    return if deps_do_only?

    ohai "Finishing up" if verbosity?

    install_plist

    keg = Keg.new(formula.prefix)
    link(keg)

    unless poured_bottle_done? and formula.bottle_specification.skip_relocation?
      fix_install_names(keg)
    end

    if formula.post_install_defined?
      if build_bottle?
        ohai "Not running post_install as we're building a bottle"
        puts "You can run it manually using `brew postinstall #{formula.full_name}`"
      else
        post_install
      end
    end

    caveats

    ohai "Summary" if verbosity? or show_summary_heading?
    puts summary

    # let's reset Utils.git_available? if we just installed git
    Utils.clear_git_available_cache if formula.name == "git"
  ensure
    unlock
  end # finish

  def summary
    s = ""
    s << "#{HOMEBREW_INSTALL_BADGE}  " if MacOS.version >= :lion and not NO_EMOJI
    s << "#{formula.prefix}:  #{formula.prefix.abv}"
    s << ", built in #{pretty_duration build_time}" if build_time

    s
  end # summary

  def build_time
    if @start_time and not interactive?
      @build_time ||= Time.now - @start_time + checkpoint_times
    end
  end

  # Returns a raw count of seconds, as logged when the checkpoints were saved.
  def checkpoint_times
    sum = 0
    formula.checkpoint_names.each do |name|
      entry = formula.checkpoint_entry(name); exit = formula.checkpoint_exit(name)
      next unless entry.exists? and exit.exists?
      sum += exit.binread.to_i - entry.binread.to_i
    end
    sum
  end # checkpoint_times

  def sanitized_ARGV_options
    args = Options.new
    args << "--mode=#{case (bm = ARGV.build_mode); when :bottL then 'plain'; when :n8ive then 'native'; else bm; end}"

    args << (ARGV.bottle_arch ? "--bottle-arch=#{Target.arch}" : '--build-bottle') if build_bottle?

    args << '--ignore-dependencies' if deps_do_ignore?
    args << '--git' if git?
    args << '--interactive' if interactive?
    args << '--verbose' if verbosity?
    args << '--debug' if debug?
    args << "--cc=#{ARGV.cc}" if ARGV.cc
    args << '--no-enhancements' if ignore_aids?

    if ARGV.env
      args << "--env=#{ARGV.env}"
    elsif formula.env.std?
      args << "--env=std"
    end

    if formula.head?
      args << "--HEAD"
    elsif formula.devel?
      args << "--devel"
    end

    args
  end # sanitized_ARGV_options

  def build_argv; (sanitized_ARGV_options | Options.create(formula.build.effective_formula_flags)).as_flags; end

  def build
    FileUtils.rm_rf(formula.logs)
    @start_time = Time.now

    # Formulæ can modify ENV, so we must ensure that each installation starts with a pristine copy.  Forking now is the easiest way
    # to do this.
    read, write = IO.pipe
    # I'm guessing this is not a good way to do this, but I'm no UNIX guru
    ENV['HOMEBREW_ERROR_PIPE'] = write.to_i.to_s

    args = [CONFIG_RUBY_PATH]
    args << '-d' if ENV['HOMEBREW_DEBUG_RUBY'].choke
    args.concat(%W[
      -W0
      -I #{HOMEBREW_LOAD_PATH}
      --
      #{HOMEBREW_RUBY_LIBRARY}/build.rb
      #{formula.path}
    ]).concat(build_argv)
    args.unshift('nice', BREW_NICE_LEVEL) if BREW_NICE_LEVEL
    $stderr.puts "Build command line:  “#{args * ' '}”" if DEBUG

    # Ruby 2.0+ sets close-on-exec by default on all file descriptors except 0, 1, & 2, so we must tell it we want the pipe to stay
    # open in the child process.  This argument is silently removed when `exec` interprets it; the system does not see it.
    args << { write => write } if RUBY_VERSION >= "2.0"

    pid = fork do
      begin
        read.close
        if Sandbox.available? and ARGV.sandbox?
          sandbox = Sandbox.new(formula)
          sandbox.exec(*args)
        else
          exec(*args)
        end
      rescue Exception => e
        Marshal.dump(e, write)
        write.close
        exit! 1
      end
    end # fork

    ignore_interrupts(:quietly) do # the child will receive the interrupt and marshal it back
      write.close
      data = read.read
      read.close
      Process.wait(pid)
      raise Marshal.load(data) unless data.nil? or data.empty?
      raise Interrupt, "User interrupted build" if $?.exitstatus == 130
      raise "Suspicious installation failure (build process silently exited)" unless $?.success?
    end # quietly ignore interrupts

    raise "Empty installation" if Dir["#{formula.prefix}/*"].empty?
  end # build

  def link(keg)
    if formula.keg_only?
      begin
        keg.optlink
      rescue Keg::LinkError => e
        onoe "Failed to create #{formula.opt_prefix}"
        puts "Things that depend on #{formula.full_name} will probably not build."
        puts e
        Homebrew.failed = true
      end
      return
    end

    if keg.linked?
      opoo "This keg was marked linked already, continuing anyway"
      keg.remove_linked_keg_record
    end

    link_overwrite_backup = {} # Hash: conflict file -> backup file
    backup_dir = HOMEBREW_CACHE/"Backup"

    begin
      keg.link
    rescue Keg::ConflictError => e
      conflict_file = e.lnk
      if formula.link_overwrite?(conflict_file) && !link_overwrite_backup.key?(conflict_file)
        backup_file = backup_dir/conflict_file.relative_path_from(HOMEBREW_PREFIX).to_s
        backup_file.parent.mkpath
        conflict_file.rename backup_file
        link_overwrite_backup[conflict_file] = backup_file
        retry
      end
      onoe "The `brew link` step did not complete successfully"
      puts "The formula built, but is not symlinked into #{HOMEBREW_PREFIX}"
      puts e
      puts
      puts "Possible conflicting files are:"
      mode = OpenStruct.new(:dry_run => true, :overwrite => true)
      keg.link(mode)
      @show_summary_heading = true
      Homebrew.failed = true
    rescue Keg::LinkError => e
      onoe "The `brew link` step did not complete successfully"
      puts "The formula built, but is not symlinked into #{HOMEBREW_PREFIX}"
      puts e
      puts
      puts "You can try again using:"
      puts "    brew link #{formula.name}"
      @show_summary_heading = true
      Homebrew.failed = true
    rescue Exception => e
      onoe "An unexpected error occurred during the `brew link` step"
      puts "The formula built, but is not symlinked into #{HOMEBREW_PREFIX}"
      puts e
      puts e.backtrace if debug?
      @show_summary_heading = true
      ignore_interrupts do
        keg.unlink
        link_overwrite_backup.each do |origin, backup|
          origin.parent.mkpath
          backup.rename origin
        end
        link_overwrite_backup = {}  # They’ve been put back; no use keeping a record.
      end
      Homebrew.failed = true
      if debug?
        puts 'Depending on just what went wrong, you may be able to'
        puts "    brew link #{formula.name}"
      else raise; end
    else
      @show_summary_heading = true
    end # keg.link

    unless link_overwrite_backup.empty?
      opoo "These files were overwritten during `brew link` step:"
      puts link_overwrite_backup.keys
      puts
      puts "They have been backed up in #{backup_dir}"
      @show_summary_heading = true
    end
  end # link

  def install_plist
    return unless formula.plist
    formula.plist_path.atomic_write(formula.plist)
    formula.plist_path.chmod 0644
    log = formula.var/"log"
    log.mkpath if formula.plist.include? log.to_s
  rescue Exception => e
    onoe "Failed to install plist file"
    ohai e, e.backtrace if debug?
    Homebrew.failed = true
  end # install_plist

  def fix_install_names(keg)
    keg.fix_install_names
  rescue Exception => e
    onoe "Failed to fix install names"
    puts "The formula built, but you may encounter issues using it or linking other"
    puts "formulæ against it."
    ohai e, e.backtrace if debug?
    Homebrew.failed = true
    @show_summary_heading = true
  end # fix_install_names

  def clean
    ohai "Cleaning" if verbosity?
    Cleaner.new(formula).clean
  rescue Exception => e
    opoo "The cleaning step did not complete successfully"
    puts "Still, the installation was successful, so we will link it into your prefix"
    ohai e, e.backtrace if debug?
    Homebrew.failed = true
    @show_summary_heading = true
  end # clean

  def post_install
    formula.run_post_install
  rescue Exception => e
    opoo "The post-install step did not complete successfully"
    puts "You can try again using `brew postinstall #{formula.full_name}`"
    ohai e, e.backtrace if debug?
    Homebrew.failed = true
    @show_summary_heading = true
  end # post_install

  def pour
    if Homebrew::Hooks::Bottles.formula_has_bottle?(formula)
      return if Homebrew::Hooks::Bottles.pour_formula_bottle(formula)
    end

    if (bottle_path = formula.local_bottle_path)
      downloader = LocalBottleDownloadStrategy.new(bottle_path)
    else
      downloader = formula.bottle
      downloader.verify_download_integrity(downloader.fetch)
    end
    HOMEBREW_CELLAR.cd do
      downloader.stage
    end

    keg = Keg.new(formula.prefix)
    keg.relocate_install_names Keg::PREFIX_PLACEHOLDER, HOMEBREW_PREFIX.to_s,
                               Keg::CELLAR_PLACEHOLDER, HOMEBREW_CELLAR.to_s \
      unless formula.bottle_specification.skip_relocation?
    keg.relocate_text_files Keg::PREFIX_PLACEHOLDER, HOMEBREW_PREFIX.to_s,
                            Keg::CELLAR_PLACEHOLDER, HOMEBREW_CELLAR.to_s

    Pathname.glob("#{formula.bottle_prefix}/{etc,var}/**/*") do |path|
      path.extend(InstallRenamed)
      path.cp_path_sub(formula.bottle_prefix, HOMEBREW_PREFIX)
    end
    FileUtils.rm_rf formula.bottle_prefix

    tab = Tab.for_keg(keg)

    CxxStdlib.check_compatibility(
      formula, formula.recursive_dependencies, keg, tab.compiler
    )

    tab.tap = formula.tap
    tab.poured_from_bottle = true
    tab.write
  end # pour

  def audit_check_output(output)
    if output
      opoo output
      @show_summary_heading = true
    end
  end # audit_check_output

  def audit_installed
    audit_check_output(check_PATH(formula.bin))
    audit_check_output(check_PATH(formula.sbin))
    super
  end

  private

  def hold_locks?; @hold_locks or false; end

  def lock
    # ruby 1.8.2 doesn't implement flock
    # TODO backport the flock feature to Tiger and reenable it
    return if RUBY_VERSION < '1.8.6'

    if (@@locked ||= []).empty?
      formula.recursive_dependencies.each do |dep|
        @@locked << dep.to_formula
      end unless deps_do_ignore?
      @@locked.unshift(formula)
      @@locked.uniq!
      @@locked.each(&:lock)
      @hold_locks = true
    end
  end # lock

  def unlock
    if hold_locks?
      @@locked.each do |lock|
        lock.unlock
        lock.clean_up_lock
      end
      @@locked.clear
      @hold_locks = false
    end
  end # unlock
end # FormulaInstaller
