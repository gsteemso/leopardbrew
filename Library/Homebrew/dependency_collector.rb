require "dependency"
require "dependencies"
require "requirement"
require "requirements"
require "set"

## A dependency is another formula that the current formula must have preïnstalled.  A requirement is anything other than a formula
## that the current formula needs to have present.  This includes external language modules, command-line tools in the path, or any
## other arbitrary predicate.
## The `depends_on` method in the formula DSL is used to declare dependencies and requirements.

# This class is used by Formula⸬depends_on to turn dependency specifications into the proper kinds of dependencies and requirements.
class DependencyCollector
  # Define the languages that we can handle as external dependencies.
  LANGUAGE_MODULES = Set[ :chicken, :jruby, :lua, :node, :ocaml, :perl, :python2, :python3, :rbx, :ruby ].freeze

  CACHE = {}

  def self.clear_cache; CACHE.clear; end

  attr_reader :deps, :requirements

  def initialize
    @deps = Dependencies.new
    @requirements = Requirements.new
  end

  def add(dspec, option_name = nil)
    case dep = fetch(dspec, option_name)
      when Dependency  then @deps << dep
      when Requirement then @requirements << dep
      when Array       then dep.each {|d| add(d)}
    end
    dep
  end # add

  def fetch(dspec, option_name); CACHE.fetch(cache_key(dspec)) { |key| CACHE[key] = build(dspec, option_name) }; end

  def cache_key(dspec)
    if Resource === dspec && dspec.download_strategy == CurlDownloadStrategy
      File.extname(dspec.url)
    else
      dspec
    end
  end # cache_key

  def build(dspec, option_name)
    dspec, tags = Hash === dspec ? dspec.first : dspec
    parse_spec(dspec, Array(tags), option_name)
  end

  private

  def parse_spec(dspec, tags, option_name)
    case dspec
      when Requirement, Dependency then dspec
      when Resource then resource_dep(dspec, tags)
      when Class    then parse_class_spec(dspec, tags)
      when String   then parse_string_spec(dspec, tags, option_name)
      when Symbol   then parse_symbol_spec(dspec, tags, option_name)
      else raise TypeError, "Unsupported type #{dspec.class.name} for #{dspec.inspect}"
    end
  end # parse_spec

  def parse_string_spec(dspec, tags, option_name)
    if HOMEBREW_TAP_FORMULA_REGEX === dspec then option_name \
                                                   ? TapDependency.new(dspec, tags, Dependency::DEFAULT_ENV_PROC, option_name) \
                                                   : TapDependency.new(dspec, tags)
    elsif tags.empty? then Dependency.new(dspec, tags, Dependency::DEFAULT_ENV_PROC, option_name || dspec)
    elsif (tag = tags.first) && LANGUAGE_MODULES.include?(tag)
      LanguageModuleRequirement.new(tag, dspec, tags[1])
    else Dependency.new(dspec, tags, Dependency::DEFAULT_ENV_PROC, option_name || dspec)
    end
  end # parse_string_spec

  def parse_symbol_spec(dspec, tags, option_name)
    case dspec
      when :ant        then ant_dep(tags, option_name)
      when :apr        then AprRequirement.new(tags, option_name)
      when :arch       then ArchRequirement.new(tags)
      when :cctools    then CctoolsRequirement.new(tags)
      when :emacs      then EmacsRequirement.new(tags, option_name)
      when :expat      then Dependency.new('expat', tags, Dependency::DEFAULT_ENV_PROC, option_name || 'expat') \
                              if MacOS.version < :leopard
      when :fortran    then FortranRequirement.new(tags, option_name)
      when :gpg        then GPGRequirement.new(tags, option_name, option_name)
      when :hg         then MercurialRequirement.new(tags, option_name)
      when :java       then JavaRequirement.new(tags, option_name)
      # Tiger’s, and sometimes Leopard’s, ld are too old to properly link some software
      when :ld64       then Dependency.new('ld64', [:build], proc { ENV.ld64 }, option_name || 'ld64') if MacOS.version <= :leopard
      when :macos      then MinimumMacOSRequirement.new(tags)
      when :mpi        then MPIRequirement.new(*tags)
      when :mysql      then MysqlRequirement.new(tags, option_name)
      when :nls        then Dependency.new('gettext', tags, Dependency::DEFAULT_ENV_PROC, option_name || 'nls')
      when :osxfuse    then OsxfuseRequirement.new(tags, option_name)
      when :postgresql then PostgresqlRequirement.new(tags, option_name)
      when :python2    then Python2Requirement.new(tags, option_name)
      when :python3    then Python3Requirement.new(tags, option_name)
      when :ruby       then RubyRequirement.new(tags, option_name)
      when :tex        then TeXRequirement.new(tags)
      when :tuntap     then TuntapRequirement.new(tags, option_name)
      when :x11        then X11Requirement.new(dspec.to_s, tags, option_name)
      when :xcode      then XcodeRequirement.new(tags)
      when :autoconf, :automake, :bsdmake, :libtool # deprecated
                       then autotools_dep(dspec, tags, option_name)
      when :cairo, :fontconfig, :freetype, :libpng, :pixman # deprecated
                       then Dependency.new(dspec.to_s, tags, Dependency::DEFAULT_ENV_PROC, option_name || dspec.to_s)
      when :libltdl # deprecated
                       then tags << :run
                            Dependency.new('libtool', tags.uniq, Dependency::DEFAULT_ENV_PROC, option_name || 'libtool')
      else raise ArgumentError, "Unsupported special dependency #{dspec.inspect}"
    end
  end # parse_symbol_spec

  def parse_class_spec(dspec, tags)
    if dspec < Requirement then dspec.new(tags)
    else raise TypeError, "#{dspec.inspect} is not a Requirement subclass"
    end
  end

  def autotools_dep(dspec, tags, option_name)
    tags << :build unless tags.include? :run
    Dependency.new(dspec.to_s, tags.uniq, Dependency::DEFAULT_ENV_PROC, option_name || dspec.to_s)
  end

  def ant_dep(tags, option_name)
    Dependency.new('ant', tags, Dependency::DEFAULT_ENV_PROC, option_name || 'ant') if MacOS.version >= :mavericks
  end

  def resource_dep(dspec, tags)
    tags << :build
    strategy = dspec.download_strategy
    case
      when strategy <= CurlDownloadStrategy      then parse_url_spec(dspec.url, tags)
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
