require "set"
require "keg"
require "formula"

class LinkageChecker
  attr_reader :keg, :formula, :brewed_dylibs, :system_dylibs, :broken_dylibs, :variable_dylibs, :undeclared_deps, :reverse_links

  def initialize(keg, formula = nil)
    @keg = keg
    @formula = formula || resolve_formula(keg)
    @brewed_dylibs = Hash.new { |h, k| h[k] = Set.new }
    @system_dylibs = Set.new
    @variable_dylibs = Set.new
    @broken_dylibs = Set.new
    @undeclared_deps = []
    @reverse_links = Hash.new { |h, k| h[k] = Set.new }
    check_dylibs
  end # initialize

  def check_dylibs
    keg.find do |file|
      next unless file.real_file? and file.tracked_mach_o?

      file.dynamically_linked_libraries.each do |dylib|  # Weakly‐linked dylibs are not necessarily present, so don’t check them.
        @reverse_links[dylib] << file
        if dylib.starts_with? '@'
          @variable_dylibs << dylib
        else
          begin owner = Keg.for dylib
          rescue NotAKegError; @system_dylibs << dylib
          rescue Errno::ENOENT; @broken_dylibs << dylib
          else
            t = Tab.for_keg(owner); tap = t.tap if t
            f_name = (not tap or CORE_OWNERS.include? tap) ? owner.name : "#{tap}/#{owner.name}"
            @brewed_dylibs[f_name] << dylib
          end
        end # does dylib start with '@'?
      end # each |dylib|
    end # find keg |file|

    @undeclared_deps = check_undeclared_deps if formula
  end # check_dylibs

  def check_undeclared_deps
    def filter_out(d_r); d_r.build? or (d_r.discretionary? and formula.build.without? d_r); end

    declared_deps = formula.deps.reject{ |dep| filter_out(dep) }.map(&:name)
    declared_req_deps = formula.requirements.reject{ |req| filter_out(req) }.map(&:default_formula).compact
    declared_aids = formula.active_enhancements.map(&:name)
    declared_dep_names = (declared_deps + declared_req_deps + declared_aids).map{ |dep| dep.split("/").last }
    @undeclared_deps = brewed_dylibs.keys.select{ |full_name|
        name = full_name.split("/").last
        next false if name == formula.name
        not declared_dep_names.include?(name) \
          and not CompilerConstants::GNU_GCC_VERSIONS.map{ |v| "gcc#{v.sub('.', '')}" }.include?(name) \
          and not name == 'llvm'  # Don’t flag compilers’ runtime libraries.
      }.sort{ |a, b|
        if    a.includes?("/") and not b.includes?("/") then 1   # Sort formulæ from taps after those from core.
        elsif b.includes?("/") and not a.includes?("/") then -1  #
        else  a <=> b; end
      }
  end # check_undeclared_deps

  def display_normal_output
    display_items "System libraries", system_dylibs
    display_items "Homebrew libraries", brewed_dylibs
    display_items "Variable-referenced libraries", variable_dylibs
    display_items "Missing libraries", broken_dylibs
    display_items "Possible undeclared dependencies", undeclared_deps
  end # display_normal_output

  def display_reverse_output
    return if reverse_links.empty?
    mapped = {}
    reverse_links.each_pair{ |k, v| mapped[k] = v.map{ |f| f.to_s.sub(%r{^#{keg}/}, '') } }
    mapped.keys.sort.each_with_index{ |dylib, i|
      puts dylib
      mapped[dylib].sort.each{ |f| puts "  #{f}" }
      puts unless i + 1 == mapped.keys.length  # Put a blank line after every slice but the last one.
    } # each sorted reverse‐link group
  end # display_reverse_output

  def display_test_output
    display_items "Missing libraries", broken_dylibs; puts "No broken dylib links" if broken_dylibs.empty?
  end

  private

  # Display a list.  List items may either be an array, or a hash of (tag -> array).
  def display_items(label, list)
    return if list.empty?
    puts "#{label}:"
    if list.is_a? Hash then list.keys.sort.each{ |tag| list[tag].sort.each{ |item| puts "  #{item} (#{tag})" } }
    else list.sort.each{ |item| puts "  #{item}" }; end
  end # display_items

  def resolve_formula(keg)
    f = Formulary.from_rack(keg.rack)
    t = Tab.for_keg(keg)
    f.build = BuildOptions.new(t.used_options, t.used_options + t.unused_options)
    f
  rescue FormulaUnavailableError
    opoo "Formula unavailable:  #{keg.name}"
  end # resolve_formula
end # LinkageChecker
