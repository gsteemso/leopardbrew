# This library is loaded before ENV gets extended.
# Ruby library:
require 'forwardable'
# Homebrew libraries:
require 'bottles'        # pulls in tab (thence ostruct, cxxstdlib, options, utils/json), macos (thence cpu), extend/ARGV
require 'build_options'
require 'checksum'
require 'compilers'
require 'dependency_collector'
require 'options'
require 'patch'
require 'resource'
require 'version'

class SoftwareSpec
  extend Forwardable

  CROSS_OPTION_TEXT = 'Build a universal binary for every possible target architecture'.freeze
  LOCAL_OPTION_TEXT = 'Build a universal binary for every target architecture this computer can run'.freeze
  NATIVE_OPTION_TEXT = 'Build a universal binary for the architectures native to this computer'.freeze
  UNIVERSAL_OPTION_TEXT = 'Build a universal binary for the default set of architectures'.freeze

  NLS_TEXT = 'Natural-Language Support (internationalization)'.freeze

  PREDEFINED_OPTIONS = {
    # The cross architecture‐set is always equal to or a superset of the local architecture‐set, which itself is always equal to or
    # a superset of the native architecture‐set, which is guaranteed to contain either one or two architectures exactly.
    # The possibilities are, from newest to oldest:
    #   - one native arch == one local arch == one cross arch       (:arm64/ " / "             28…)
    #                                                               (:x86_64/ " / "            :lion…:catalina)
    #                                                               (:ppc/ " / "               …:panther)
    #   - one native arch; two local archs == two cross archs       (arm64/:universal_2/ "     :big_sur…27)
    #   - one native arch == one local arch; two cross archs        (:x86_64/ " /:universal_2  :big_sur…:sequoia)
    #                                                               (:i386/ " /:universal_1    :tiger…:snow_leopard)
    #                                                               (:ppc/ " /:universal_1     :tiger…:snow_leopard)
    #   - two native archs; three local archs; four cross archs     (:intel/triple/quad        :tiger…:snow_leopard, GCC)
    #   - two native archs; three local archs == three cross archs  (:intel/triple/ "          :tiger…:snow_leopard, Clang)
    #   - two native archs == two local archs; four cross archs     (:powerpc/ " /quad         :tiger…:snow_leopard)
    :universal => (Target.cross_archs.fat? \
                    ? (Target.native_archs.fat? \
                      ? ((Target.local_archs != Target.cross_archs and Target.local_archs != Target.native_archs) \
                        ? [ # The native, local, and cross architecture‐sets all differ.
                            [ 'universal', UNIVERSAL_OPTION_TEXT ],
                            [ 'cross',     CROSS_OPTION_TEXT ],
                            [ 'local',     LOCAL_OPTION_TEXT ],
                            [ 'native',    NATIVE_OPTION_TEXT ],
                          ] \
                        : [ # The native and cross architecture‐sets differ, and the local set is redundant with one of them.
                            [ 'universal', UNIVERSAL_OPTION_TEXT ],
                            [ 'cross',     CROSS_OPTION_TEXT ],
                            [ 'native',    NATIVE_OPTION_TEXT ],
                          ] \
                        ) \
                      : # The only architecture-set that can be built is the cross set, whether or not the local set is equal to it.
                        # To have two options that do the same thing is useless, and potentially confusing to the user.
                        [ [ 'cross', CROSS_OPTION_TEXT ] ] \
                      ) \
                    : # No architecture‐sets are fat.
                      [] \
                  ),
    :tests     => [ [ 'with-tests', 'Run the build-time unit tests (can be slow)' ] ],
    :longtests => [ [ 'with-tests',      'Run the normal build-time unit tests (can be slow)' ],
                    [ 'with-long-tests', 'Run even the long build-time unit tests (very slow)' ],
                  ],
    :head      => [ [ 'HEAD', 'Build the version from the head of the development tree' ] ],
    :devel     => [ [ 'devel', 'Build the development version' ] ],
  }.freeze

  attr_reader :name, :full_name, :owner
  attr_reader :bottle_specification, :build, :compiler_failures, :dependency_collector, :deprecated_actuals, :deprecated_options,
              :active_enhancements, :named_enhancements, :patches, :resources

  def_delegators :@resource, :cached_download, :checksum, :clear_cache, :fetch, :mirror, :mirrors, :specs, :stage, :using,
                             :verify_download_integrity, :version, *Checksum::TYPES

  def initialize
    @active_enhancements = []
    @bottle_specification = BottleSpecification.new
    @compiler_failures = []
    @dependency_collector = DependencyCollector.new
    @deprecated_actuals = []
    @deprecated_options = []
    @flags = ARGV.effective_flags
    @named_enhancements = []
    @patches = []
    @resource = Resource.new
    @resources = {}

    @build = BuildOptions.new(Options.create(@flags), Options.new)
  end # SoftwareSpec#initialize

  def owner=(owner)
    @name = owner.name
    @full_name = owner.full_name
    @bottle_specification.tap = owner.tap
    @owner = owner
    @resource.owner = self
    resources.each_value do |r|
      r.owner     = self
      r.version ||= version
    end
    patches.each { |p| p.owner = self }
  end # SoftwareSpec#owner=

  def url(val = nil, specs = {})
    return @resource.url unless val
    @resource.url(val, specs)
    dependency_collector.add(@resource)
  end

  def bottle_unneeded?; bottle_disabled? and @bottle_disable_reason.unneeded?; end

  def bottle_disabled?; !!bottle_disable_reason; end

  def bottle_disable_reason; @bottle_disable_reason; end

  def bottled?; bottle_specification.tag?(bottle_tag) and (bottle_specification.compatible_cellar? or ARGV.force_bottle?); end

  def bottle(disable_type = nil, disable_reason = nil, &block)
    if disable_type then @bottle_disable_reason = BottleDisableReason.new(disable_type, disable_reason)
    else bottle_specification.instance_eval(&block); end
  end

  def resource_defined?(name); resources.key?(name); end

  def resource(name, klass = Resource, &block)
    if block_given?
      raise DuplicateResourceError, name if resource_defined?(name)
      res = klass.new(name, &block)
      resources[name] = res
      dependency_collector.add(res)
    else resources.fetch(name) { raise ResourceMissingError.new(owner, name) }; end
  end # SoftwareSpec#resource

  def go_resource(name, &block); resource name, Resource::Go, &block; end

  def option_defined?(opt); build.options.include?(opt); end

  def option(name, description = '')
    opts = PREDEFINED_OPTIONS.fetch(name) do
        if name == :cxx11
          opoo 'The :cxx11 option is obsolete', 'Formulæ that won’t build without it should use a “needs” clause' if DEVELOPER
          name = name.to_s
        elsif name == '32-bit'
          opoo 'The “32-bit” option is obsolete', 'Formulæ that won’t build without it should use an ArchRequirement' if DEVELOPER
        elsif Symbol === name
          opoo "Passing arbitrary symbols to `option` is deprecated:  #{name.inspect}",
            'Symbols are reserved for future use – please pass a string instead'
          name = name.to_s
        elsif not String === name then raise ArgumentError, 'option name in Formula (as passed to SoftwareSpec) is not a String'
        elsif name.empty? then raise ArgumentError, 'option name is required'
        elsif name.length < 2 then raise ArgumentError, 'option name must be longer than one character'
        elsif name.starts_with?('-') then raise ArgumentError, 'option name must not start with a dash'
        end
        [ [ name, description ] ]
      end # PREDEFINED_OPTIONS fetch‐failure block
    unless opts.empty?
      opts_ = []
      opts.each_with_index{ |args, i| opts_ << Option.new(args[0], (i == 0 and description != '') ? description : args[1]) }
      build.options += opts_
    end
  end # SoftwareSpec#option

  def deprecated_option(hash)
    raise ArgumentError, 'deprecated_option hash must not be empty' if hash.empty?
    hash.each do |old_optstrings, new_optstrings|
      Array(old_optstrings).each do |old_optstring|
        new_optstring = Array(new_optstrings).first
        d_o = DeprecatedOption.new(old_optstring, new_optstring)
        deprecated_options << d_o
        if @flags.include? d_o.old_flag
          @flags -= [d_o.old_flag]
          @flags |= [d_o.current_flag]
          @deprecated_actuals << d_o
        end
        @build.fix_deprecation(d_o)  # does nothing unless the old flag is actually present
      end # each |old optstring|
    end # each |{old, new} optstrings|
  end # SoftwareSpec#deprecated_option

  def depends_on(d_spec); if (dep = dependency_collector.add d_spec) then add_dep_option dep; end; end

#  def depends_1_of(group)
#    group = Hash.new(group => []) unless group.is_a? Hash
#    group_name, group_members = *(group.keys.first)
#    group_tags = Array(group.values.first)
#    d_set = dependency_collector.add_set(group)
#    add_set_options(d_set) if d_set
#  end # SoftwareSpec#depends_1_of

  def depends_group(group)
    group_name, members = Array(group)
    group_tags = Array(members.values.first)
    members = Array(members.keys.first)
    if (gdep = GroupDependency.new group_name, group_tags, members, dependency_collector) and not gdep.subdeps.empty?
      add_dep_option gdep; end
  end # SoftwareSpec#depends_group

  def enhanced_by(aid)
    # Enhancements may be specified either individually, or as a mutually‐necessary group.  Named enhancements are therefore stored
    #   as one large array of small, usually single-element, arrays of formulæ.  The active enhancements are merely a flat array of
    #   formulæ.  All of these are kept sorted for convenience.
    # Note:  The “active” enhancements describe what would be true of a new build done at run time.  They do not describe the state
    #   of any installed keg – use Keg#enhanced_by?() for that.
    aids = Array(aid).map{ |name| Formula[name == :nls ? 'gettext' : name] rescue nil }.compact
    unless aids.empty?
      @named_enhancements << aids.sort{ |a, b| a.full_name <=> b.full_name }
      @named_enhancements = named_enhancements.sort{ |a, b| sort_named_enhancements(a, b) }
    end
    @active_enhancements = active_enhancements.concat(aids).uniq.sort{ |a, b| a.full_name <=> b.full_name } \
      if aids.all?{ |f| f and f.installed? }
  end # SoftwareSpec#enhanced_by

  def deps; dependency_collector.deps; end

  def requirements; dependency_collector.requirements; end

  def patch(strip = :p1, src = nil, &block); patches << Patch.create(strip, src, &block); end

  def fails_with(compiler, &block); @compiler_failures << CompilerFailure.create(compiler, &block); end

  def needs(*stds); stds.each{ |std| @compiler_failures.concat CompilerFailure.for_standard(std) }; end

  def add_legacy_patches(list)
    list = Patch.normalize_legacy_patches(list)
    list.each { |p| p.owner = self }
    patches.concat(list)
  end

  def add_dep_option(dep)
    if Array === dep
      dep.each { |d| add_dep_option(d) }
    else
      nm = dep.option_name
      if dep.optional? and not option_defined?("with-#{nm}")
        build.options << Option.new("with-#{nm}", nm == 'nls' ? "Build with #{NLS_TEXT}" : "Build with #{nm} support")
      elsif dep.recommended? and not option_defined?("without-#{nm}")
        build.options << Option.new("without-#{nm}", nm == 'nls' ? "Build without #{NLS_TEXT}" : "Build without #{nm} support")
      end
    end # Array of deps?
  end # SoftwareSpec#add_dep_option

  private

  def sort_named_enhancements(a, b)
    # The named enhancements are an array of sorted arrays of formulæ.  Sort based on the elements’
    # full formula names, with shorter arrays sorting first if otherwise equal.
    a.compact!; b.compact!
    i = 0; while (i < a.length and i < b.length and a[i].full_name == b[i].full_name) do i += 1; end
    if i < a.length # elements differ, or else b is shorter
      i < b.length ? a[i].full_name <=> b[i].full_name : 1
    else # a is shorter, or else they were equal
      i < b.length ? -1 : 0
    end
  end

end # SoftwareSpec

class HeadSoftwareSpec < SoftwareSpec
  def initialize; super; @resource.version = Version.new('HEAD'); end
  def verify_download_integrity(_fn); nil; end
end # HeadSoftwareSpec

class Bottle
  class Filename
    attr_reader :name, :version, :tag, :revision
    alias_method :rebuild, :revision

    def self.create(formula, tag, revision); new(formula.name, formula.pkg_version, tag, revision); end

    def initialize(name, version, tag, revision)
      @name = name; @version = version; @tag = tag; @revision = revision
    end

    def to_s; prefix + suffix; end

    def prefix; "#{name}-#{version}.#{tag}"; end

    def suffix; s = revision > 0 ? ".#{revision}" : ''; ".bottle#{s}.tar.gz"; end
  end # Bottle::Filename

  extend Forwardable

  attr_reader :name, :resource, :prefix, :cellar, :revision

  def_delegators :resource, :url, :fetch, :verify_download_integrity
  def_delegators :resource, :cached_download, :clear_cache

  def initialize(formula, spec)
    @name = formula.name
    @resource = Resource.new
    @resource.owner = formula
    @spec = spec
    checksum, tag = spec.checksum_for(bottle_tag)
    filename = Filename.create(formula, tag, spec.revision)
    @resource.url(build_url(spec.root_url, filename))
    @resource.download_strategy = CurlBottleDownloadStrategy
    @resource.version = formula.pkg_version
    @resource.checksum = checksum
    @prefix = spec.prefix
    @cellar = spec.cellar
    @revision = spec.revision
  end # Bottle#initialize

  def compatible_cellar?; @spec.compatible_cellar?; end

  # Does the bottle need to be relocated?
  def skip_relocation?; @spec.skip_relocation?; end

  def stage; resource.downloader.stage; end

  private

  def build_url(root_url, filename); "#{root_url}/#{filename}"; end
end # Bottle

class BottleSpecification
  DEFAULT_PREFIX = '/usr/local'.freeze
  DEFAULT_CELLAR = '/usr/local/Cellar'.freeze
  DEFAULT_DOMAIN = (ENV['HOMEBREW_BOTTLE_DOMAIN'] ||
                    'https://ia904500.us.archive.org/24/items/tigerbrew').freeze

  attr_rw :prefix, :cellar, :revision
  alias_method :rebuild, :revision
  attr_accessor :tap
  attr_reader :checksum, :collector

  def initialize
    revision(0)
    prefix(DEFAULT_PREFIX)
    cellar(DEFAULT_CELLAR)
    @collector = BottleCollector.new
  end # BottleSpecification#initialize

  def root_url(var = nil); if var.nil? then @root_url ||= DEFAULT_DOMAIN else @root_url = var; end; end

  def compatible_cellar?
    [:any, :any_skip_relocation, HOMEBREW_CELLAR.to_s].any? { |c| cellar == c }
  end

  # Does the Bottle this BottleSpecification belongs to need to be relocated?
  def skip_relocation?; cellar == :any_skip_relocation; end

  def tag?(tag); !!checksum_for(tag); end

  # Checksum methods in the DSL's bottle block optionally take
  # a Hash, which indicates the platform the checksum applies on.
  Checksum::TYPES.each do |cksum|
    define_method(cksum) do |val|
      digest, tag = val.shift
      collector[tag] = Checksum.new(cksum, digest)
    end # BottleSpecification#⟨cksum⟩
  end # each Checksum::TYPES |cksum|

  def checksum_for(tag); collector.fetch_checksum_for(tag); end

  def checksums
    checksums = {}
    os_versions = collector.keys
    os_versions.map! { |vrsn| MacOS::Version.from_encumbered_symbol vrsn rescue nil }.compact!
    os_versions.sort.reverse_each do |os_version|
      vrsn = os_version.to_sym
      checksum = collector[vrsn]
      checksums[checksum.hash_type] ||= []
      checksums[checksum.hash_type] << { checksum => vrsn }
    end
    checksums
  end # BottleSpecification#checksums
end # BottleSpecification
