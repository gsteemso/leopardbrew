require "ostruct"  # A Ruby library.
# These others are Homebrew libraries:
require "cxxstdlib"
require "options"
require "utils/json"

# Inherit from OpenStruct to gain a generic initialization method that takes a
# hash and creates an attribute for each key and value. `Tab.new` probably
# should not be called directly; instead use one of the class methods like
# `Tab.create`.
class Tab < OpenStruct
  FILENAME = "INSTALL_RECEIPT.json"

  def self.create(formula, compiler, stdlib, build_opts, archs)
    attributes = {
      'built_archs'     => archs,
      "built_as_bottle" => build_opts.bottle?,
      "compiler"        => compiler,
      "git_head_SHA1"   => Homebrew.git_head,
      "poured_from_bottle" => false,
      "source"          => {
        "path" => formula.path.to_s,
        "spec" => formula.active_spec_sym.to_s,
        "tap"  => formula.tap,
      },
      "stdlib"          => stdlib,
      "tabfile"         => formula.prefix/FILENAME,
      "time"            => Time.now.to_i,
      "unused_options"  => build_opts.unused_options.as_flags,
      "used_options"    => build_opts.used_options.as_flags,
    }

    new(attributes)
  end # Tab::create

  def self.empty
    attributes = {
      'built_archs'     => [],
      "built_as_bottle" => false,
      "compiler"        => nil,
      "git_head_SHA1"   => nil,
      "poured_from_bottle" => false,
      "source"          => {
        "path" => nil,
        "spec" => 'stable',
        "tap"  => nil,
      },
      "stdlib"          => nil,
      "tabfile"         => nil,
      "time"            => nil,
      "unused_options"  => [],
      "used_options"    => [],
    }
    new(attributes)
  end # Tab::empty

  def self.for_formula(f)
    paths = []
    if (p = f.prefix).directory? then paths << p; end
    if (p = f.opt_prefix).symlink? and p.directory? then paths << p.resolved_path; end
    if (p = f.linked_keg).symlink? and p.directory? then paths << p.resolved_path; end
    if (p = f.rack).directory? and (d = p.subdirs).length == 1 then paths << d.first; end
    if (p = paths.map { |pn| pn.join(FILENAME) }.find(&:file?))
      tab = from_file(p)
      used_options = remap_deprecated_options(f.deprecated_options, tab.used_options)
      tab.used_options = used_options.as_flags
    else
      tab = empty
      tab.unused_options = f.options.as_flags
      tab.source = { "path" => f.path.to_s, "spec" => f.active_spec_sym.to_s, "tap" => f.tap }
    end
    tab
  end # Tab::for_formula

  def self.for_keg(kegpath); (path = kegpath/FILENAME).exists? ? from_file(path) : empty; end

  def self.for_name(name); for_formula(Formulary.factory(name)); end

  def self.remap_deprecated_options(deprecated_options, options)
    deprecated_options.each do |deprecated_option|
      option = options.find { |o| o.name == deprecated_option.old }
      next unless option
      options -= [option]
      options << Option.new(deprecated_option.current, option.description)
    end
    options
  end # Tab::remap_deprecated_options

  def self.from_file(path); from_file_content(File.read(path), path); end

  def self.from_file_content(content, path)
    attrs = Utils::JSON.load(content)
    attrs["tabfile"] = path
    attrs["source"] ||= {}
    tp_fm = attrs["tapped_from"]
    attrs["source"]["tap"] = attrs.delete("tapped_from") if tp_fm and tp_fm != "path or URL"
    attrs["source"]["tap"] = "Homebrew/homebrew" if attrs["source"]["tap"] == "mxcl/master"
    if attrs["source"]["spec"].nil?
      version = PkgVersion.parse path.to_s.split("/")[-2]
      attrs["source"]["spec"] = version.head? ? "head" : "stable"
    end
    new(attrs)
  end # Tab::from_file_content


  def with?(val)
    name = val.respond_to?(:name) ? val.name : val
    include?("with-#{name}") or unused_options.include?("without-#{name}")
  end

  def without?(name); not with? name; end

  def include?(opt); used_options.include? opt; end

  def build_32_bit?; include?("32-bit"); end

  def cxx11?; include?("c++11"); end

  def universal?; include?("universal"); end


  def bottle?; built_as_bottle; end

  def build_bottle?; built_as_bottle and not poured_from_bottle; end

  def built_archs
    # Older tabs won’t have this field, so compute a plausible default.
    (super and super.map(&:to_sym).extend(ArchitectureListExtension)) or
      universal? ? Hardware::CPU.universal_archs : Hardware::CPU.preferred_arch_as_list
  end

  def compiler; super or MacOS.default_compiler; end

  def cxxstdlib
    # Older tabs won't have these values, so provide sensible defaults
    lib = stdlib.to_sym if stdlib
    CxxStdlib.create(lib, compiler.to_sym)
  end

  def spec; source["spec"].to_sym; end

  def tap; source["tap"]; end

  def tap=(tap); source["tap"] = tap; end

  def to_json
    attributes = {
      'built_archs'     => built_archs.map(&:to_s),
      "built_as_bottle" => built_as_bottle,
      "compiler"        => (compiler.to_s if compiler),
      "git_head_SHA1"   => git_head_SHA1,
      "poured_from_bottle" => poured_from_bottle,
      "source"          => source,
      "stdlib"          => (stdlib.to_s if stdlib),
      "time"            => time,
      "unused_options"  => unused_options.as_flags,
      "used_options"    => used_options.as_flags,
    }
    Utils::JSON.dump(attributes)
  end # to_json

  def to_s
    s = []
    case poured_from_bottle
      when true  then s << "Poured from bottle"
      when false then s << "Built from source"
    end
    unless used_options.empty?
      s << "Installed" if s.empty?
      s << "with:"
      s << used_options.to_a.join(" ")
    end
    s.join(" ")
  end # to_s

  def used_options; Options.create(super); end

  def unused_options; Options.create(super); end

  def write; tabfile.atomic_write(to_json); end
end # Tab
