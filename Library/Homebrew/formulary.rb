require "vendor/backports/enumerable"  # provides #max_by
require "digest/md5"
require "formula/renames"

# The Formulary is responsible for creating instances of Formula.
# It is not meant to be used directy from formulae.

class Formulary
  FORMULAE = {}

  def self.formula_class_defined?(path); FORMULAE.key?(path); end

  def self.formula_class_get(path); FORMULAE.fetch(path); end

  def self.load_formula(name, path, contents, namespace)
    mod = Module.new
    const_set(namespace, mod)
    mod.module_eval(contents, path)
    class_name = class_s(name)

    begin
      mod.const_get(class_name)
    rescue NameError => e
      raise FormulaUnavailableError, name, e.backtrace
    end
  end # Formulary::load_formula

  def self.load_formula_from_path(name, path)
    contents = path.open("r") { |f| set_encoding(f).read }
    namespace = "FormulaNamespace#{Digest::MD5.hexdigest(path.to_s)}"
    klass = load_formula(name, path, contents, namespace)
    FORMULAE[path] = klass
  end # Formulary::load_formula_from_path

  if IO.method_defined?(:set_encoding)
    def self.set_encoding(io)
      io.set_encoding(Encoding::UTF_8)
    end
  else
    def self.set_encoding(io)
      io
    end
  end

  def self.class_s(name)
    class_name = name.capitalize
    class_name.gsub!(/[-_.\s]([a-zA-Z0-9])/) { $1.upcase }
    class_name.tr!("+", "x")
    class_name.sub!(/(.)@(\d)/, "\\1AT\\2")
    class_name
  end # Formulary::class_s

  # A FormulaLoader returns instances of formulae.
  # Subclasses implement loaders for particular sources of formulae.
  class FormulaLoader
    # The formula's name
    attr_reader :name
    # The formula's ruby file's path or filename
    attr_reader :path

    def initialize(name, path)
      @name = name
      @path = path.resolved_path
    end

    # Gets the formula instance.
    def get_formula(spec); klass.new(name, path, spec); end

    def klass
      load_file unless Formulary.formula_class_defined?(path)
      Formulary.formula_class_get(path)
    end

    private

    def load_file
      STDERR.puts "#{$0} (#{self.class.name}): loading #{path}" if DEBUG
      raise FormulaUnavailableError, name unless path.file?
      Formulary.load_formula_from_path(name, path)
    end
  end # FormulaLoader

  # Loads formulae from bottles.
  class BottleLoader < FormulaLoader
    def initialize(bottle_name)
      @bottle_filename = Pathname(bottle_name).realpath
      name, full_name = bottle_resolve_formula_names @bottle_filename
      super name, Formulary.path(full_name)
    end

    def get_formula(spec)
      formula = super
      formula.local_bottle_path = @bottle_filename
      formula_version = formula.pkg_version
      bottle_version =  bottle_resolve_version(@bottle_filename)
      unless formula_version == bottle_version
        raise BottleVersionMismatchError.new(@bottle_filename, bottle_version, formula, formula_version)
      end
      formula
    end # BottleLoader#get_formula
  end # BottleLoader

  class AliasLoader < FormulaLoader
    def initialize(alias_path)
      path = alias_path.resolved_path
      name = path.basename(".rb").to_s
      super name, path
    end
  end # AliasLoader

  # Loads formulae from disk using a path
  class FromPathLoader < FormulaLoader
    def initialize(path)
      path = Pathname.new(path).expand_path
      super path.basename(".rb").to_s, path
    end
  end # FromPathLoader

  # Loads formulae from URLs
  class FromUrlLoader < FormulaLoader
    attr_reader :url

    def initialize(url)
      @url = url
      uri = URI(url)
      formula = File.basename(uri.path, ".rb")
      super formula, HOMEBREW_FORMULA_CACHE/File.basename(uri.path)
    end # FromUrlLoader#initialize

    def load_file
      HOMEBREW_FORMULA_CACHE.mkpath
      FileUtils.rm_f(path)
      curl url, "-o", path
      super
    end # FromUrlLoader#load_file
  end # FromUrlLoader

  # Loads tapped formulae.
  class TapLoader < FormulaLoader
    attr_reader :tap

    def initialize(tapped_name)
      user, repo, name = tapped_name.split("/", 3).map(&:downcase)
      @tap = Tap.fetch user, repo.sub(/^homebrew-/, "")
      name = @tap.formula_renames.fetch(name, name)
      path = @tap.formula_files.detect { |file| file.basename(".rb").to_s == name }

      unless path
        if (possible_alias = @tap.path/"Aliases/#{name}").file?
          path = possible_alias.resolved_path
          name = path.basename(".rb").to_s
        else
          path = @tap.path/"#{name}.rb"
        end
      end

      super name, path
    end # TapLoader#initialize

    def get_formula(spec)
      super
    rescue FormulaUnavailableError => e
      raise TapFormulaUnavailableError.new(tap, name), "", e.backtrace
    end
  end # TapLoader

  class NullLoader < FormulaLoader
    def initialize(name); super name, Formulary.core_path(name); end
    def get_formula(_spec); raise FormulaUnavailableError, name; end
  end

  # Load formulae directly from their contents
  class FormulaContentsLoader < FormulaLoader
    # The formula's contents
    attr_reader :contents

    def initialize(name, path, contents)
      @contents = contents
      super name, path
    end

    def klass
      STDERR.puts "#{$0} (#{self.class.name}): loading #{path}" if DEBUG
      namespace = "FormulaNamespace#{Digest::MD5.hexdigest(contents)}"
      Formulary.load_formula(name, path, contents, namespace)
    end
  end # FormulaContentsLoader

  # Return a Formula instance for the given reference.
  # `ref` is string containing:
  # * a formula name
  # * a formula pathname
  # * a formula URL
  # * a local bottle reference
  def self.factory(ref, spec = :stable); loader_for(ref).get_formula(spec); end

  # Return a Formula instance for a specific keg.  Returns nil if the formula
  # file is no longer present or describes a different version.  (This relies
  # on the keg containing a tab; if it doesn’t, the formula is presumed MIA.)
  def self.from_keg(keg)
    if tab = Tab.for_keg(keg)
      f_path = tab.source['path']
      f_spec = tab.spec
      f = factory(f_path, f_spec) if f_path and Pathname.new(f_path).file?
      f if f and f.version == keg.version
    end
  end # Formulary::from_keg

  # Return a Formula instance for the given rack.
  # It will auto resolve formula's spec when requested spec is nil
  def self.from_rack(rack, spec = nil)
    kegs = rack.directory? ? rack.subdirs.map { |d| Keg.new(d) } : []

    keg = kegs.detect(&:optlinked?) || kegs.detect(&:linked?) || kegs.max_by(&:version)
    return factory(rack.basename.to_s, spec || :stable) unless keg

    tab = Tab.for_keg(keg)
    tap = tab.tap
    spec ||= tab.spec

    if tap.nil? || tap == "mistydemeo/tigerbrew"
      factory(rack.basename.to_s, spec)
    else
      factory("#{tap.sub("homebrew-", "")}/#{rack.basename}", spec)
    end
  end # Formulary::from_rack

  # Return a Formula instance directly from contents
  def self.from_contents(name, path, contents, spec = :stable)
    FormulaContentsLoader.new(name, path, contents).get_formula(spec)
  end

  def self.to_rack(ref)
    # First, check whether the rack with the given name exists.
    if (rack = HOMEBREW_CELLAR/File.basename(ref, ".rb")).directory?
      return rack.resolved_path
    end

    # Second, use canonical name to locate rack.
    (HOMEBREW_CELLAR/canonical_name(ref)).resolved_path
  end # Formulary::to_rack

  def self.canonical_name(ref)
    loader_for(ref).name
  rescue TapFormulaAmbiguityError
    # If there are multiple tap formulae with the name of ref,
    # then ref is the canonical name
    ref.downcase
  end # Formulary::canonical_name

  def self.path(ref); loader_for(ref).path; end

  def self.loader_for(ref)
    case ref
    when %r{(https?|ftp|file)://}
      return FromUrlLoader.new(ref)
    when Pathname::BOTTLE_EXTNAME_RX
      return BottleLoader.new(ref)
    when HOMEBREW_CORE_FORMULA_REGEX
      name = $1
      formula_with_that_name = core_path(name)
      if (newname = FORMULA_RENAMES[name]) && !formula_with_that_name.file?
        return FormulaLoader.new(newname, core_path(newname))
      else
        return FormulaLoader.new(name, formula_with_that_name)
      end
    when HOMEBREW_TAP_FORMULA_REGEX
      return TapLoader.new(ref)
    end

    if File.extname(ref) == ".rb"
      return FromPathLoader.new(ref)
    end

    formula_with_that_name = core_path(ref)
    if formula_with_that_name.file?
      return FormulaLoader.new(ref, formula_with_that_name)
    end

    possible_alias = Pathname.new("#{HOMEBREW_LIBRARY}/Aliases/#{ref}")
    if possible_alias.file?
      return AliasLoader.new(possible_alias)
    end

    possible_tap_formulae = tap_paths(ref)
    if possible_tap_formulae.size > 1
      raise TapFormulaAmbiguityError.new(ref, possible_tap_formulae)
    elsif possible_tap_formulae.size == 1
      path = possible_tap_formulae.first.resolved_path
      name = path.basename(".rb").to_s
      return FormulaLoader.new(name, path)
    end

    if newref = FORMULA_RENAMES[ref]
      formula_with_that_oldname = core_path(newref)
      if formula_with_that_oldname.file?
        return FormulaLoader.new(newref, formula_with_that_oldname)
      end
    end

    possible_tap_newname_formulae = []
    Tap.each do |tap|
      if newref = tap.formula_renames[ref]
        possible_tap_newname_formulae << "#{tap.name}/#{newref}"
      end
    end

    if possible_tap_newname_formulae.size > 1
      raise TapFormulaWithOldnameAmbiguityError.new(ref, possible_tap_newname_formulae)
    elsif !possible_tap_newname_formulae.empty?
      return TapLoader.new(possible_tap_newname_formulae.first)
    end

    possible_cached_formula = Pathname.new("#{HOMEBREW_FORMULA_CACHE}/#{ref}.rb")
    if possible_cached_formula.file?
      return FormulaLoader.new(ref, possible_cached_formula)
    end

    NullLoader.new(ref)
  end # Formulary::loader_for

  def self.core_path(name); Pathname.new("#{HOMEBREW_LIBRARY}/Formula/#{name.downcase}.rb"); end

  def self.tap_paths(name, taps = Dir["#{HOMEBREW_LIBRARY}/Taps/*/*/"])
    name = name.downcase
    taps.map do |tap|
      Pathname.glob([
        "#{tap}Formula/#{name}.rb",
        "#{tap}HomebrewFormula/#{name}.rb",
        "#{tap}#{name}.rb",
        "#{tap}Aliases/#{name}",
      ]).detect(&:file?)
    end.compact
  end # Formulary::tap_paths

  def self.find_with_priority(ref, spec = :stable)
    possible_pinned_tap_formulae = tap_paths(ref, Dir["#{HOMEBREW_LIBRARY}/PinnedTaps/*/*/"]).map(&:realpath)
    if possible_pinned_tap_formulae.size > 1
      raise TapFormulaAmbiguityError.new(ref, possible_pinned_tap_formulae)
    elsif possible_pinned_tap_formulae.size == 1
      selected_formula = factory(possible_pinned_tap_formulae.first, spec)
      if core_path(ref).file?
        opoo <<-EOS.undent
          #{ref} is provided by core, but is now shadowed by #{selected_formula.full_name}.
          To refer to the core formula, use Homebrew/homebrew/#{ref} instead.
        EOS
      end
      selected_formula
    else
      factory(ref, spec)
    end
  end # Formulary::find_with_priority
end # Formulary
