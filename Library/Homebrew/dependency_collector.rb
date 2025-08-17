require "dependency"
require "dependencies"
require "requirement"
require "requirements"
require "set"

## A dependency is a formula that another formula needs to install.
## A requirement is something other than a formula that another formula
## needs to be present. This includes external language modules,
## command-line tools in the path, or any arbitrary predicate.
##
## The `depends_on` method in the formula DSL is used to declare
## dependencies and requirements.

# This class is used by `depends_on` in the formula DSL to turn dependency
# specifications into the proper kinds of dependencies and requirements.
class DependencyCollector
  # Define the languages that we can handle as external dependencies.
  LANGUAGE_MODULES = Set[
    :chicken, :jruby, :lua, :node, :ocaml, :perl, :python, :python3, :rbx, :ruby
  ].freeze

  CACHE = {}

  def self.clear_cache; CACHE.clear; end

  attr_reader :deps, :requirements

  def initialize
    @deps = Dependencies.new
    @requirements = Requirements.new
  end

  def add(spec)
    case dep = fetch(spec)
      when Dependency  then @deps << dep
      when Requirement then @requirements << dep
      when Array       then dep.each {|d| add(d)}
    end
    dep
  end # add

  def fetch(spec); CACHE.fetch(cache_key(spec)) { |key| CACHE[key] = build(spec) }; end

  def cache_key(spec)
    if Resource === spec && spec.download_strategy == CurlDownloadStrategy
      File.extname(spec.url)
    else
      spec
    end
  end # cache_key

  def build(spec)
    spec, tags = Hash === spec ? spec.first : spec
    parse_spec(spec, Array(tags))
  end

  private

  def parse_spec(spec, tags)
    case spec
      when Requirement, Dependency then spec
      when Resource then resource_dep(spec, tags)
      when Class    then parse_class_spec(spec, tags)
      when String   then parse_string_spec(spec, tags)
      when Symbol   then parse_symbol_spec(spec, tags)
      else raise TypeError, "Unsupported type #{spec.class.name} for #{spec.inspect}"
    end
  end # parse_spec

  def parse_string_spec(spec, tags)
    if HOMEBREW_TAP_FORMULA_REGEX === spec then TapDependency.new(spec, tags)
    elsif tags.empty? then Dependency.new(spec, tags)
    elsif (tag = tags.first) && LANGUAGE_MODULES.include?(tag)
      LanguageModuleRequirement.new(tag, spec, tags[1])
    else Dependency.new(spec, tags)
    end
  end # parse_string_spec

  def parse_symbol_spec(spec, tags)
    case spec
      when :ant        then ant_dep(spec, tags)
      when :apr        then AprRequirement.new(tags)
      when :arch       then ArchRequirement.new(tags)
      when :c11        then C11Requirement.new(tags)
      when :cctools    then CctoolsRequirement.new(tags)
      when :cxx11      then Cxx11Requirement.new(tags)
      when :emacs      then EmacsRequirement.new(tags)
      when :expat      then Dependency.new('expat', tags) if MacOS.version < :leopard
      when :fortran    then FortranRequirement.new(tags)
      when :gpg        then GPGRequirement.new(tags)
      when :hg         then MercurialRequirement.new(tags)
      when :java       then JavaRequirement.new(tags)
      # Tiger’s, and sometimes Leopard’s, ld are too old to properly link some software
      when :ld64
        Dependency.new('ld64', [:build], proc { ENV.ld64 }) if MacOS.version <= :leopard
      when :macos      then MinimumMacOSRequirement.new(tags)
      when :mpi        then MPIRequirement.new(*tags)
      when :mysql      then MysqlRequirement.new(tags)
      when :nls        then Dependency.new('gettext', tags, nil, 'nls')
      when :osxfuse    then OsxfuseRequirement.new(tags)
      when :postgresql then PostgresqlRequirement.new(tags)
      when :python, :python2 then PythonRequirement.new(tags)
      when :python3    then Python3Requirement.new(tags)
      when :ruby       then RubyRequirement.new(tags)
      when :tex        then TeXRequirement.new(tags)
      when :tuntap     then TuntapRequirement.new(tags)
      when :x11        then X11Requirement.new(spec.to_s, tags)
      when :xcode      then XcodeRequirement.new(tags)
      when :autoconf, :automake, :bsdmake, :libtool # deprecated
        autotools_dep(spec, tags)
      when :cairo, :fontconfig, :freetype, :libpng, :pixman # deprecated
        Dependency.new(spec.to_s, tags)
      when :clt # deprecated
      when :libltdl # deprecated
        tags << :run
        Dependency.new("libtool", tags)
      else raise ArgumentError, "Unsupported special dependency #{spec.inspect}"
    end
  end # parse_symbol_spec

  def parse_class_spec(spec, tags)
    if spec < Requirement then spec.new(tags)
    else raise TypeError, "#{spec.inspect} is not a Requirement subclass"
    end
  end

  def autotools_dep(spec, tags)
    tags << :build unless tags.include? :run
    Dependency.new(spec.to_s, tags)
  end

  def ant_dep(spec, tags); Dependency.new(spec.to_s, tags) if MacOS.version >= :mavericks; end

  def resource_dep(spec, tags)
    tags << :build
    strategy = spec.download_strategy
    case
      when strategy <= CurlDownloadStrategy      then parse_url_spec(spec.url, tags)
      when strategy <= GitDownloadStrategy       then GitRequirement.new(tags)
      when strategy <= MercurialDownloadStrategy then MercurialRequirement.new(tags)
      when strategy <= FossilDownloadStrategy    then Dependency.new("fossil", tags)
      when strategy <= BazaarDownloadStrategy    then Dependency.new("bazaar", tags)
      when strategy <= CVSDownloadStrategy
        Dependency.new("cvs", tags) if MacOS.version >= :mavericks or not MacOS::Xcode.provides_cvs?
      when strategy < AbstractDownloadStrategy  # allow unknown strategies to pass through
      else raise TypeError, "#{strategy.inspect} is not an AbstractDownloadStrategy subclass"
    end
  end # resource_dep

  def parse_url_spec(url, tags)
    case File.extname(url)
      when '.7z'  then Dependency.new('p7zip', tags)
      when '.lz'  then Dependency.new('lzip', tags)
      when '.rar' then Dependency.new('unrar', tags)
      when '.xz'  then Dependency.new('xz', tags)
      when '.zst' then Dependency.new('zstd', tags)
    end
  end # parse_url_spec
end # DependencyCollector
