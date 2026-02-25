# This file is loaded before `global.rb`, so must eschew many Homebrew‐isms at eval time.

require 'version'

module MacOS
  MAX_SUPPORTED_VERSION = '15'

  class Version < ::Version
    SYMBOLS = {                                         :panther       => '10.3',   :tiger     => '10.4',   :leopard  => '10.5',
      :snow_leopard => '10.6',   :lion     => '10.7',   :mountain_lion => '10.8',   :mavericks => '10.9',   :yosemite => '10.10',
      :el_capitan   => '10.11',  :sierra   => '10.12',  :high_sierra   => '10.13',  :mojave    => '10.14',  :catalina => '10.15',
      :big_sur      => '11',     :monterey => '12',     :ventura       => '13',     :sonoma    => '14',     :sequoia  => '15',
      :tahoe        => '26',
    }.freeze

    DARWINS = {
      '10.3'  =>  7,  # Panther – end of :ppc‐only
      '10.4'  =>  8,  # Tiger – start of :intel, of Rosetta (:ppc only) / Universal, and of 64‐bit
      '10.5'  =>  9,  # Leopard – end of :powerpc‐native
      '10.6'  => 10,  # Snow Leopard – end of Rosetta, and of :i386 as valid Leopardbrew target
      '10.7'  => 11,  # Lion – start of 64‐bit CPU requirement
      '10.8'  => 12,
      '10.9'  => 13,
      '10.10' => 14,
      '10.11' => 15,
      '10.12' => 16,
      '10.13' => 17,
      '10.14' => 18,  # Mojave – end of :i386 execution
      '10.15' => 19,  # Catalina – start of :x86_64‐only
      '11'    => 20,  # Big Sur – start of :arm64 and Rosetta 2 / Universal 2
      '12'    => 21,
      '13'    => 22,
      '14'    => 23,
      '15'    => 24,  # Sequoia – end of :intel‐native
      '26'    => 26,
    # '27'    => 27,  # end of Rosetta 2 / Universal 2
    # '28'    => 28,  # start of :arm64‐only
    }.freeze

    def self.from_encumbered_symbol(sym)
      str = sym.to_s
      new(MacOS::Version::SYMBOLS.fetch(str[%r{^[^_]+}].to_sym) {
            MacOS::Version::SYMBOLS.fetch(str[%r{^[^_]+_[^_]+}].to_sym) {
              raise ArgumentError, "unknown version #{sym.inspect}"
          } }
         )
    end # MacOS::Version::from_encumbered_symbol()

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
    end # MacOS::Version#<=>()

    def to_sym; SYMBOLS.invert.fetch(@version, :dunno); end

    def pretty_name; to_sym.to_s.split("_").map(&:capitalize).join(' '); end

    def as_Darwin; DARWINS.fetch(@version) { raise ArgumentError, "unknown version #{@version.inspect}" }; end
  end # MacOS::Version

  # This can be compared to numerics, strings, or symbols using the standard Ruby Comparable methods.
  def version; @version ||= Version.new(MACOS_VERSION); end

  def codename; version.to_sym; end

  def darwin; version.as_Darwin; end

  def display_name; version.pretty_name; end

  # This can be compared to numerics, strings, or symbols using the standard Ruby Comparable methods.
  def full_version; @full_version ||= Version.new(MACOS_FULL_VERSION); end
end # MacOS
