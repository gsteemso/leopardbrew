require "tab"
require "macos"
require "extend/ARGV"

def built_as_bottle?(f)
  return false unless f.installed?
  tab = Tab.for_keg(f.prefix)
  tab.built_as_bottle
end

def bottle_file_outdated?(f, file)
  filename = file.basename.to_s
  return unless f.bottle and filename.match(Pathname::BOTTLE_EXTNAME_RX)
  bottle_ext = filename[bottle_native_regex, 1]
  bottle_url_ext = f.bottle.url[bottle_native_regex, 1]

  bottle_ext and bottle_url_ext and bottle_ext != bottle_url_ext
end # bottle_file_outdated?

def bottle_native_regex
  /(\.#{bottle_tag}\.bottle\.(\d+\.)?tar\.gz)$/o
end

def bottle_tag
  if MacOS.version >= :big_sur
    if Target.type == :arm
      "#{MacOS.codename}_arm".to_sym
    else
      "#{MacOS.codename}_intel".to_sym
    end
  elsif MacOS.version >= :snow_leopard  # Catalina and under can run 32‐bit, but after Leopard we
    MacOS.codename                      # only build 64‐bit (too many obsolescences with 32‐bit).
  else
    # Return, e.g., :tiger_g3, :leopard_g5_64, :leopard_intel_64
    case Target.arch
      when :altivec          then "#{MacOS.codename}_altivec".to_sym
      when :i386             then "#{MacOS.codename}_intel_32".to_sym
      when :ppc              then "#{MacOS.codename}_#{Target.model}".to_sym
      when :ppc64            then "#{MacOS.codename}_g5_64".to_sym
      when :x86_64, :x86_64h then "#{MacOS.codename}_intel_64".to_sym
      else "#{MacOS.codename}_unknown".to_sym
    end
  end
end # bottle_tag

def bottle_arch_is_valid?
  ARGV.bottle_arch and (CPU::KNOWN_TYPES + CPU.known_archs + CPU.known_models + [:altivec, :g5_64,
                        :intel_32, :intel_64]).includes? ARGV.bottle_arch
end

def bottle_receipt_path(bottle_file)
  Utils.popen_read(TAR_PATH, "-tzf", bottle_file, "*/*/INSTALL_RECEIPT.json").chomp
end

def bottle_resolve_formula_names(bottle_file)
  receipt_file_path = bottle_receipt_path bottle_file
  receipt_file = Utils.popen_read(TAR_PATH, "-xOzf", bottle_file, receipt_file_path)
  name = receipt_file_path.split("/").first
  tap = Tab.from_file_content(receipt_file, "#{bottle_file}/#{receipt_file_path}").tap
  if tap.nil? or tap == "Homebrew/homebrew"
    full_name = name
  else
    full_name = "#{tap.sub("homebrew-", "")}/#{name}"
  end

  [name, full_name]
end # bottle_resolve_formula_names

def bottle_resolve_version(bottle_file)
  PkgVersion.parse bottle_receipt_path(bottle_file).split("/")[1]
end

class Bintray
  def self.package(formula_name); formula_name.to_s.tr("+", "x"); end

  def self.repository(tap = nil)
    return "bottles" if tap.nil? or tap == "Homebrew/homebrew"
    "bottles-#{tap.sub(%r{^homebrew/(homebrew-)?}i, "")}"
  end
end # Bintray

class BottleCollector
  def initialize; @checksums = {}; end

  def fetch_checksum_for(tag)
    tag = find_matching_tag(tag)
    return self[tag], tag if tag
  end

  def keys; @checksums.keys; end

  def [](key); @checksums[key]; end

  def []=(key, value); @checksums[key] = value; end

  def key?(key); @checksums.key?(key); end

  private

  def find_matching_tag(tag)
    key?(tag) ? tag : (find_altivec_tag(tag) or find_or_later_tag(tag))
  end

  # This allows generic Altivec PPC bottles to be supported in some
  # formulae, while also allowing specific bottles in others; e.g.,
  # sometimes a formula has just :tiger_altivec, other times it has
  # :tiger_g4, :tiger_g5, etc.
  def find_altivec_tag(tag)
    if tag.to_s =~ /(\w+)_(g4|g4e|g5)$/
      altivec_tag = "#{$1}_altivec".to_sym
      altivec_tag if key?(altivec_tag)
    end
  end # find_altivec_tag

  # Allows a bottle tag to specify a specific OS or later,
  # so the same bottle can target multiple OSs.
  # Not used in core, used in taps.
  def find_or_later_tag(tag)
    begin
      tag_version = MacOS::Version.from_symbol(tag)
    rescue ArgumentError
      return
    end

    keys.find do |key|
      if key.to_s.end_with?("_or_later")
        later_tag = key.to_s[/(\w+)_or_later$/, 1].to_sym
        MacOS::Version.from_symbol(later_tag) <= tag_version
      end
    end
  end # find_or_later_tag
end # BottleCollector
