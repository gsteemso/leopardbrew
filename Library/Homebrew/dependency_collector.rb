require "dependency"
require "dependencies"
require "requirement"
require "requirements"
require "set"

## A dependency is another formula that the current formula must have preïnstalled.  A requirement is anything other than a formula
## that the current formula needs to have present.  This includes external language modules, command-line tools in the path, or any
## other arbitrary predicate.
## The `depends_on` method in the formula DSL is used to declare dependencies and requirements.

# This class is used by Formula::depends_on to turn dependency specifications into the proper kinds of dependencies & requirements.
class DependencyCollector
  # Define the languages that we can handle as external dependencies.
  LANGUAGE_MODULES = Set[ :chicken, :jruby, :lua, :node, :ocaml, :perl, :python2, :python3, :rbx, :ruby ].freeze

  CACHE = {}

  attr_reader :deps, :requirements

  def initialize
    @deps = Dependencies.new
    @requirements = Requirements.new
  end

  def add(dspec)
    case dep = fetch(dspec)
      when Dependency  then @deps << dep
      when Requirement then @requirements << dep
      when Array       then dep.each{ |d| add d }
    end
    dep
  end # add

  def build(dspec)
    dspec, tags = Hash === dspec ? dspec.first : dspec
    parse_spec(dspec, Array(tags))
  end

  def cache_key(dspec)
    return File.extname(dspec.url) if dspec.is_a?(Resource) and dspec.download_strategy.is_a? CurlDownloadStrategy
    dspec
  end # cache_key

  def fetch(dspec); CACHE.fetch(cache_key(dspec)) { |key| CACHE[key] = build(dspec) }; end

  def self.clear_cache; CACHE.clear; end

  private

  def deprecated_symbol_dep(dep_sym, dep_name = dep_sym.to_s, tags = [])
    opoo "The special dependency “#{':' if dep_name.is_a? Symbol}#{dep_name}” was incorrectly specified as “#{dep_sym.inspect}”"
    Dependency.new(dep_name.to_s, tags)
  end

  def parse_class_spec(dspec, tags)
    dspec < Requirement ? dspec.new(tags) : raise(TypeError, "“#{dspec.inspect}” is not a Requirement subclass")
  end

  def parse_spec(dspec, tags)
    case dspec
      when Class    then parse_class_spec(dspec, tags)
      when Dependency, Requirement then dspec
      when Resource then resource_dep(dspec, tags)
      when String   then parse_string_spec(dspec, tags)
      when Symbol   then parse_symbol_spec(dspec, tags)
      else raise TypeError, "Unsupported type #{dspec.class.name} for #{dspec.inspect}"
    end
  end # parse_spec

  def parse_string_spec(dspec, tags)
    if HOMEBREW_TAP_FORMULA_REGEX === dspec
      return TapDependency.new(dspec, tags)
    elsif not tags.empty?
      language, import_name, brewed = tags
      if LANGUAGE_MODULES.include?(language) then return LanguageModuleRequirement.new(language, dspec, import_name, brewed); end
    end
    Dependency.new(dspec, tags)
  end # parse_string_spec

  def parse_symbol_spec(dspec, tags)
    case dspec
      when :ant        then Dependency.new('ant', tags) if MacOS.version >= :mavericks
      when :apr        then AprRequirement.new(tags)
      when :arch       then ArchRequirement.new(tags)
      when :cctools    then CctoolsRequirement.new(tags)
      when :emacs      then EmacsRequirement.new(tags)
      when :expat      then Dependency.new('expat', tags) if MacOS.version < :leopard
      when :fortran    then FortranRequirement.new(tags)
      when :gpg        then GPGRequirement.new(tags)
      when :hg         then MercurialRequirement.new(tags)
      when :java       then JavaRequirement.new(tags)
      # Tiger’s, and sometimes Leopard’s, ld are too old to properly link some software.
      when :ld64       then Dependency.new('ld64', [:build]) { ENV.ld64 } if MacOS.version <= :leopard
      when :macos      then MinimumMacOSRequirement.new(tags)
      when :mpi        then MPIRequirement.new(*tags)
      when :mysql      then MysqlRequirement.new(tags)
      when :nls        then Dependency.new('gettext', tags, 'nls')
      when :nls_iconv  then GroupDependency.new('nls', tags, ['gettext', 'libiconv'], self)
      when :osxfuse    then OsxfuseRequirement.new(tags)
      when :postgresql then PostgresqlRequirement.new(tags)
      when :python2    then Python2Requirement.new(tags)
      when :python3    then Python3Requirement.new(tags)
      when :ruby       then RubyRequirement.new(tags)
      when :tex        then TeXRequirement.new(tags)
      when :tuntap     then TuntapRequirement.new(tags)
      when :x11        then X11Requirement.new(dspec.to_s, tags)
      when :xcode      then XcodeRequirement.new(tags)
      # Deprecated symbols:
      when :autoconf, :automake, :bsdmake, :libtool
                       then tags << :build unless tags.include? :run; deprecated_symbol_dep(dspec, nil, tags.uniq)
      when :cairo, :fontconfig, :freetype, :libpng, :pixman
                       then deprecated_symbol_dep(dspec, nil, tags)
      when :libltdl    then tags << :run; deprecated_symbol_dep(dspec, 'libtool', tags.uniq)
      when :python     then deprecated_symbol_dep(dspec, :python2, tags)
      else raise ArgumentError, "Unsupported special dependency #{dspec.inspect}"
    end
  end # parse_symbol_spec

  def parse_url_spec(url, tags)
    case File.extname(url)
      when '.7z'  then Dependency.new('p7zip', tags)
      when '.lz'  then Dependency.new('lzip', tags)
      when '.rar' then Dependency.new('unrar', tags)
      when '.xz'  then Dependency.new('xz', tags)
      when '.zst' then Dependency.new('zstd', tags)
    end
  end # parse_url_spec

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
end # DependencyCollector
