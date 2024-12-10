# This file is loaded before `global.rb`, so must eschew many Homebrew‐isms at
# eval time.

require 'version'

module OS
  module Mac
    MAX_SUPPORTED_VERSION = '15'

    class Version < ::Version
      SYMBOLS = {
        :sequoia       => '15',
        :sonoma        => '14',
        :ventura       => '13',
        :monterey      => '12',
        :big_sur       => '11',
        :catalina      => '10.15',
        :mojave        => '10.14',
        :high_sierra   => '10.13',
        :sierra        => '10.12',
        :el_capitan    => '10.11',
        :yosemite      => '10.10',
        :mavericks     => '10.9',
        :mountain_lion => '10.8',
        :lion          => '10.7',
        :snow_leopard  => '10.6',
        :leopard       => '10.5',
        :tiger         => '10.4',
        :panther       => '10.3'
      }.freeze

      def self.from_symbol(sym)
        str = SYMBOLS.fetch(sym) { raise ArgumentError, "unknown version #{sym.inspect}" }
        new(str)
      end

      def initialize(*args); super; @comparison_cache = {}; end

      def <=>(other)
        @comparison_cache.fetch(other) do
            v = SYMBOLS.fetch(other) { other.to_s }
            @comparison_cache[other] = super(Version.new(v))
          end
      end # <=>

      def to_sym; SYMBOLS.invert.fetch(@version) { :dunno }; end

      def pretty_name; to_sym.to_s.split("_").map(&:capitalize).join(' '); end
    end # OS::Mac::Version

    # This can be compared to numerics, strings, or symbols
    # using the standard Ruby Comparable methods.
    def version
      @version ||= Version.new(MACOS_VERSION)
    end

    def codename; version.to_sym; end

    # This can be compared to numerics, strings, or symbols
    # using the standard Ruby Comparable methods.
    def full_version
      @full_version ||= Version.new(MACOS_FULL_VERSION)
    end

  end # OS::Mac
end # OS
