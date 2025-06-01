require "set"
require "keg"
require "formula"

class LinkageChecker
  attr_reader :keg, :formula, :brewed_dylibs, :system_dylibs, :broken_dylibs,
              :variable_dylibs, :undeclared_deps, :reverse_links

  def initialize(keg, formula = nil)
    @keg = keg
    @formula = formula || resolve_formula(keg)
    @brewed_dylibs = Hash.new { |h, k| h[k] = Set.new }
    @system_dylibs = Set.new
    @broken_dylibs = Set.new
    @variable_dylibs = Set.new
    @undeclared_deps = []
    @reverse_links = Hash.new { |h, k| h[k] = Set.new }
    check_dylibs
  end # initialize

  def check_dylibs
    @keg.find do |file|
      next if file.symlink? or file.directory?
      next unless file.tracked_mach_o?

      # weakly loaded dylibs may not actually exist on disk, so skip them
      # when checking for broken linkage
      file.dynamically_linked_libraries.each do |dylib|
        @reverse_links[dylib] << file
        if dylib.starts_with? '@'
          @variable_dylibs << dylib
        else
          begin
            owner = Keg.for Pathname.new(dylib)
          rescue NotAKegError
            @system_dylibs << dylib
          rescue Errno::ENOENT
            @broken_dylibs << dylib
          else
            t = Tab.for_keg(owner).tap
            f = ([nil, 'mistydemeo/tigerbrew', 'gsteemso/leopardbrew'].include?(t) ? owner.name : "#{tap}/#{owner.name}")
            @brewed_dylibs[f] << dylib
          end
        end # does dylib start with '@'?
      end # each |dylib|
    end # find keg |file|

    @undeclared_deps = check_undeclared_deps if formula
  end # check_dylibs

  def check_undeclared_deps
    def filter_out(dep)
      dep.build? or ((dep.optional? or dep.recommended?) and formula.build.without?(dep))
    end
    declared_deps = formula.deps.reject{ |dep| filter_out(dep) }.map(&:name)
    declared_req_deps = formula.requirements.reject{ |req| filter_out(req) }.map(&:default_formula).compact
    declared_aids = formula.active_enhancements.map(&:name)
    declared_dep_names = (declared_deps + declared_req_deps + declared_aids).map{ |dep| dep.split("/").last }
    undeclared_deps = @brewed_dylibs.keys.select do |full_name|
      name = full_name.split("/").last
      next false if name == formula.name
      !declared_dep_names.include?(name)
    end
    undeclared_deps.sort do |a, b|
      if    a.include?("/") and not b.include?("/") then 1
      elsif b.include?("/") and not a.include?("/") then -1
      else a <=> b; end
    end
  end # check_undeclared_deps

  def display_normal_output
    display_items "System libraries", @system_dylibs
    display_items "Homebrew libraries", @brewed_dylibs
    display_items "Variable-referenced libraries", @variable_dylibs
    display_items "Missing libraries", @broken_dylibs
    display_items "Possible undeclared dependencies", @undeclared_deps
  end # display_normal_output

  def display_reverse_output
    return if @reverse_links.empty?
    sorted = @reverse_links.sort
    sorted.each do |dylib, files|
      puts dylib
      files.each do |f|
        unprefixed = f.to_s.sub %r{^#{@keg}/}, ''
        puts "  #{unprefixed}"
      end
      puts unless dylib == sorted.last[0]
    end # each sorted |dylib, files|
  end # display_reverse_output

  def display_test_output
    display_items "Missing libraries", @broken_dylibs
    puts "No broken dylib links" if @broken_dylibs.empty?
  end

  def broken_dylibs?; !@broken_dylibs.empty?; end

  def undeclared_deps?; !@undeclared_deps.empty?; end

  private

  # Display a list of things.
  # Things may either be an array, or a hash of (label -> array)
  def display_items(label, things)
    return if things.empty?
    puts "#{label}:"
    if things.is_a? Hash
      things.sort.each do |list_label, list|
        list.sort.each do |item|
          puts "  #{item} (#{list_label})"
        end
      end
    else
      things.sort.each do |item|
        puts "  #{item}"
      end
    end
  end # display_items

  def resolve_formula(keg)
    f = Formulary.from_rack(keg.rack)
    t = Tab.for_keg(keg)
    f.build = BuildOptions.new(t.used_options, t.used_options + t.unused_options)
    f
  rescue FormulaUnavailableError
    opoo "Formula unavailable: #{keg.name}"
  end # resolve_formula
end # LinkageChecker
