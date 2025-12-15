require 'ostruct'  # A Ruby library.
# These others are Homebrew libraries:
require 'cxxstdlib'
require 'options'
require 'utils/json'

# Inherit from OpenStruct to gain a generic initialization method that takes a hash and creates an attribute for each key and value.
#`Tab.new` probably should not be called directly; instead use one of the class methods like `Tab.create`.
class Tab < OpenStruct
  FILENAME = 'INSTALL_RECEIPT.json'

  class << self
    def create(formula, compiler, stdlib, archs)
      attributes = {
        'active_aids'        => formula.active_enhancements,
        'build_mode'         => formula.build.mode.to_s,
        'built_archs'        => archs,
        'built_as_bottle'    => formula.build.bottle?,
        'compiler'           => compiler,
        'git_head_SHA1'      => Homebrew.git_head,
        'poured_from_bottle' => false,
        'source'             => {
          'path' => formula.path.to_s,
          'spec' => formula.active_spec_sym.to_s,
          'tap'  => formula.tap,
        },
        'stdlib'             => stdlib,
        'tabfile'            => formula.prefix/FILENAME,
        'time'               => Time.now.to_i,
        'unused_options'     => formula.build.unused_options.as_flags,
        'used_options'       => formula.build.used_options.as_flags,
      }
      new(attributes)
    end # Tab::create

    def empty
      attributes = {
        'active_aids'        => [],
        'build_mode'         => 'plain',
        'built_archs'        => [],
        'built_as_bottle'    => false,
        'compiler'           => nil,
        'git_head_SHA1'      => nil,
        'poured_from_bottle' => false,
        'source'             => {
          'path' => nil,
          'spec' => 'stable',
          'tap'  => nil,
        },
        'stdlib'             => nil,
        'tabfile'            => nil,
        'time'               => nil,
        'unused_options'     => [],
        'used_options'       => [],
      }
      new(attributes)
    end # Tab::empty

    def for_formula?(f, prefer = :current)  # Pass _anything_ else to prefer an active version over the latest one.
      paths = []
      if prefer == :current
        if (p = f.spec_prefix :stable) and p.directory? then paths << p; end
        if (p = f.spec_prefix :devel) and p.directory? then paths << p; end
        if (p = f.spec_prefix :head) and p.directory? then paths << p; end
        if (p = f.opt_prefix).symlink? and p.directory? then paths << p.resolved_path; end
        if (p = f.linked_keg).symlink? and p.directory? then paths << p.resolved_path; end
        if (p = f.rack).directory? and (d = p.subdirs).length == 1 then paths << d.first; end
      else
        if (p = f.opt_prefix).symlink? and p.directory? then paths << p.resolved_path; end
        if (p = f.linked_keg).symlink? and p.directory? then paths << p.resolved_path; end
        if (p = f.rack).directory? and (d = p.subdirs).length == 1 then paths << d.first; end
        if (p = f.spec_prefix :stable) and p.directory? then paths << p; end
        if (p = f.spec_prefix :devel) and p.directory? then paths << p; end
        if (p = f.spec_prefix :head) and p.directory? then paths << p; end
      end
      paths.map{ |pn| pn/FILENAME }.find(&:file?)
    end

    def for_formula(f, prefer = :current)  # Pass _anything_ else to prefer an active version over the latest one.
      if p = for_formula?(f, prefer)
        tab = from_file(p)
        used_options = remap_deprecated_options(f.deprecated_options, tab.used_options)
        tab.used_options = used_options.as_flags
      else
        tab = empty
        tab.unused_options = f.options.as_flags
        tab.source = { 'path' => f.path.to_s, 'spec' => f.active_spec_sym.to_s, 'tap' => f.tap }
      end
      tab
    end # Tab::for_formula

    def for_keg(kegpath); (path = kegpath/FILENAME).file? ? from_file(path) : empty; end

    # This is made for use before formulæ have been parsed, so we can’t do things like ask them for their deprecated options.  This
    # means we can’t get a completely up‐to‐date set of used options, but fortunately, the difference is rarely going to matter.
    def for_rack?(rack)
      return unless rack.directory?
      rackname = rack.basename; paths = []
      if (p = OPTDIR/rackname).symlink? and p.directory? then paths << p.resolved_path; end
      if (p = LINKDIR/rackname).symlink? and p.directory? then paths << p.resolved_path; end
      if (p = PINDIR/rackname).symlink? and p.directory? then paths << p.resolved_path; end
      if (p = rack.subdirs).length == 1 then paths << p.first; end
      from_file(p) if p = paths.map{ |pn| pn/FILENAME }.find(&:file?)
    end # Tab::for_rack?

    def for_name(name); for_formula(Formulary.factory(name)); end

    def remap_deprecated_options(deprecated_options, options)
      deprecated_options.each do |deprecated_option|
        option = options.find { |o| o.name == deprecated_option.old }
        next unless option
        options -= [option]
        options << Option.new(deprecated_option.current, option.description)
      end
      options
    end # Tab::remap_deprecated_options

    def from_file(path); from_file_content(File.read(path), path); end

    def from_file_content(content, path)
      attrs = Utils::JSON.load(content)
      attrs['active_aids'] ||= (attrs['active_aid_sets'] ? attrs['active_aid_sets'].flatten(1) : [])
      attrs['active_aids'].map!{ |fa| Formulary.from_keg(HOMEBREW_CELLAR/fa[0]/fa[1]) }.compact!  # can be nil if missing
      attrs['built_archs'] ||= []
      attrs['source'] ||= {}
      pn = Pathname.new(attrs['source']['path'])
      if not pn.exists? and pn.dirname == HOMEBREW_LIBRARY/'Formula'
        b = pn.basename.to_s
        if (pn = pn.dirname/b[0]/b).exists? then attrs['source']['path'] = pn.to_s; end
      end
      if attrs['source']['spec'].nil?
        version = PkgVersion.parse path.to_s.split('/')[-2]
        attrs['source']['spec'] = version.head? ? 'head' : 'stable'  # usually correct, devel is rare
      end
      tp_fm = attrs['tapped_from']
      attrs['source']['tap'] = attrs.delete('tapped_from') if tp_fm and tp_fm != 'path or URL'
      attrs['source']['tap'] = 'Homebrew/homebrew' if attrs['source']['tap'] == 'mxcl/master'
      attrs['tabfile'] = path
      new(attrs)
    end # Tab::from_file_content
  end # << self

  def with?(val)
    name = val.responds_to?(:name) ? val.name : val
    includes?("with-#{name}") or unused_options.include?("without-#{name}")
  end

  def without?(val)
    name = val.responds_to?(:name) ? val.name : val
    includes?("without-#{name}") or unused_options.include?("with-#{name}")
  end

  def includes?(opt); used_options.include? opt; end
  alias_method :include?, :includes?

  def build_32_bit?; includes?('32-bit'); end

  # Deprecated
  def cxx11?; includes?('c++11'); end

  def cross?; includes?('cross'); end

  def local?; includes?('local'); end

  def native?; includes?('native'); end

  def universal?; includes?('universal'); end

  def bottle?; built_as_bottle; end

  def build_bottle?; built_as_bottle and not poured_from_bottle; end

  # Older tabs won’t have this field, so supply an empty list.
  def active_aids; super || []; end

  # Older tabs won’t have this field, so compute the most probable value.
  def build_mode; (super.to_sym if super) || (:plain if poured_from_bottle) || ((tabfile and tabfile.exists?) ? Keg.for(tabfile).reconstruct_build_mode : nil); end

  def built_archs
    # Older tabs won’t have this field, so compute a plausible default.
    if super.empty? then if universal? then case build_mode
                                              when :cross then Target.cross_archs
                                              when :local then Target.local_archs
                                              when :native then CPU.native_archs
                                              when :plain then Target.preferred_arch_as_list
                                            end
                         else Target.preferred_arch_as_list; end
    else super.map(&:to_sym).extend ArchitectureListExtension; end
  end # built_archs

  def compiler; super or MacOS.default_compiler; end

  def cxxstdlib
    # Older tabs won’t have these values, so provide sensible defaults.
    lib = stdlib.to_sym if stdlib
    CxxStdlib.create(lib, compiler.to_sym)
  end

  def spec; source['spec'].to_sym; end

  def tap; source['tap']; end

  def tap=(tap); source['tap'] = tap; end

  def to_json
    attributes = {
      'active_aids'        => active_aids.compact.map{ |f| [f.full_name, f.pkg_version.to_s] },
      'build_mode'         => build_mode.to_s.choke,
      'built_archs'        => built_archs.map(&:to_s),
      'built_as_bottle'    => built_as_bottle,
      'compiler'           => compiler.to_s,
      'git_head_SHA1'      => git_head_SHA1,
      'poured_from_bottle' => poured_from_bottle,
      'source'             => source,
      'stdlib'             => stdlib.to_s.choke,
      'time'               => time,
      'unused_options'     => unused_options.as_flags,
      'used_options'       => used_options.as_flags,
    }
    Utils::JSON.dump(attributes)
  end # to_json

  def to_s
    s = []
    s << case poured_from_bottle
           when true  then 'Poured from bottle'
           when false then 'Built from source'
           else 'Installed'
         end
    bm = case build_mode
           when :cross  then ' [cross-build mode]'
           when :local  then ' [local build mode]'
           when :native then ' [native build mode]'
           when nil     then ' [unknown build mode]'
           else ''
         end
    s << "(for #{built_archs.map(&:to_s).list}#{bm})"
    s << 'with: ' << used_options.to_a.sort.list unless used_options.empty?
    s << "\nEnhanced by:  #{active_aids.compact.map{ |f| "#{f.full_name} #{f.pkg_version}" }.list}" if active_aids.choke
    s * ' '
  end # to_s

  def used_options; Options.create(super); end

  def unused_options; Options.create(super); end

  def write; tabfile.atomic_write(to_json); end
end # Tab
