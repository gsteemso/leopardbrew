# This file is loaded before `global.rb`, so must eschew many Homebrew‐isms at eval time.

require 'version'

module MacOS
  MAX_SUPPORTED_VERSION = '15'

  class Version < ::Version
    SYMBOLS = {       # Mac OS    Darwin
      :tahoe         => '26',     # 26
      :sequoia       => '15',     # 24
      :sonoma        => '14',     # 23
      :ventura       => '13',     # 22
      :monterey      => '12',     # 21
      :big_sur       => '11',     # 20 – start of :arm64 and Rosetta 2 / Universal 2
      :catalina      => '10.15',  # 19 – start of :x86_64‐only
      :mojave        => '10.14',  # 18 – end of :i386
      :high_sierra   => '10.13',  # 17
      :sierra        => '10.12',  # 16
      :el_capitan    => '10.11',  # 15
      :yosemite      => '10.10',  # 14
      :mavericks     => '10.9',   # 13
      :mountain_lion => '10.8',   # 12
      :lion          => '10.7',   # 11 – start of 64‐bit CPU requirement
      :snow_leopard  => '10.6',   # 10 – end of Rosetta
      :leopard       => '10.5',   #  9 – end of :powerpc
      :tiger         => '10.4',   #  8 – start of :intel, of Rosetta (:ppc only) / Universal, and of 64‐bit
      :panther       => '10.3'    #  7
    }.freeze

    def self.from_encumbered_symbol(sym)
      str = sym.to_s
      new(MacOS::Version::SYMBOLS.fetch(str[%r{^[^_]+}].to_sym) {
            MacOS::Version::SYMBOLS.fetch(str[%r{^[^_]+_[^_]+}].to_sym) {
              raise ArgumentError, "unknown version #{sym.inspect}"
          } }
         )
    end

    def self.from_symbol(sym)
      str = SYMBOLS.fetch(sym) { raise ArgumentError, "unknown version #{sym.inspect}" }
      new(str)
    end

    def initialize(*args);
      args[0] = SYMBOLS.fetch(args[0], :dunno) if Symbol === args[0]
      super
      @comparison_cache = {}
    end

    def <=>(other)
      @comparison_cache.fetch(other) do
          v = SYMBOLS.fetch(other) { other.to_s }
          @comparison_cache[other] = super(Version.new(v))
        end
    end # <=>

    def to_sym; SYMBOLS.invert.fetch(@version, :dunno); end

    def pretty_name; to_sym.to_s.split("_").map(&:capitalize).join(' '); end
  end # MacOS::Version

  # This can be compared to numerics, strings, or symbols
  # using the standard Ruby Comparable methods.
  def version; @version ||= Version.new(MACOS_VERSION); end

  def codename; version.to_sym; end

  # This can be compared to numerics, strings, or symbols
  # using the standard Ruby Comparable methods.
  def full_version
    @full_version ||= Version.new(MACOS_FULL_VERSION)
  end
end # MacOS
