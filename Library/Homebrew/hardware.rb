# This file is loaded before `global.rb`, so must eschew many Homebrew‐isms at
# eval time.

require 'mach'

class Hardware
  module CPU
    extend self

    # TODO:  Match to compiler version
    MODEL_FLAGS = {
      :g3          => [32, :powerpc, '-mcpu=750'],
      :g4          => [32, :powerpc, '-mcpu=7400'],
      :g4e         => [32, :powerpc, '-mcpu=7450'],
      :g5          => [64, :powerpc, '-mcpu=970'],
      :core        => [32, :intel,   '-march=prescott'],
      :core2       => [64, :intel,   '-march=core2'],
      :penryn      => [64, :intel,   '-march=core2 -msse4.1'],
      :nehalem     => [64, :intel,   '-march=core2 -msse4.2'],
      :arrandale   => [64, :intel,   '-march=core2 -msse4.2'],
      :sandybridge => [64, :intel,   '-march=core2 -msse4.2'],
      :ivybridge   => [64, :intel,   '-march=core2 -msse4.2'],
      :haswell     => [64, :intel,   '-march=core2 -msse4.2'],
      :broadwell   => [64, :intel,   '-march=core2 -msse4.2'],
    }.freeze
    def known_models; MODEL_FLAGS.keys; end
    def optimization_flags(model); MODEL_FLAGS[model][2]; end
    def opt_flags_as_map; h = {}; MODEL_FLAGS.each_pair { |k, v| h[k] = v[2] }; h; end
    def hw_type(model); MODEL_FLAGS[model][1]; end
    def bit_width(model); MODEL_FLAGS[model][0]; end

  # The following harvest sysctl spewage.  See <mach/machine.h> to decode.

    def type
      @type ||= case sysctl_int('hw.cputype')
                  when  7 then :intel
                  when 12 then :arm
                  when 18 then :powerpc
                  else :dunno
                end
    end # type

    %w[arm intel powerpc].each { |t| define_method("#{t}?") { type == t } }
    alias_method :ppc?, :powerpc?  # Backwards compatibility – MANY existing uses.

    def arch
      case type
        when :arm     then :arm64
        when :intel   then is_64_bit? ? :x86_64 : :i386
        when :powerpc then is_64_bit? ? :ppc64  : :ppc
      end
    end

    def model
      case type
        when :intel
          case sysctl_int('hw.cpufamily')
            when 0x73d67300 then :core        # Yonah: Core Solo/Duo
            when 0x426f69ef then :core2       # Merom: Core 2 Duo
            when 0x78ea4fbc then :penryn      # Penryn
            when 0x6b5a4cd2 then :nehalem     # Nehalem
            when 0x573B5EEC then :arrandale   # Arrandale (on Wikipedia see under “Westmere”)
            when 0x5490B78C then :sandybridge # Sandy Bridge
            when 0x1F65E835 then :ivybridge   # Ivy Bridge
            when 0x10B282DC then :haswell     # Haswell
            when 0x582ed09c then :broadwell   # Broadwell
            else :dunno
          end
        when :powerpc
          case sysctl_int('hw.cpusubtype')
            when 0x09 then :g3  # PowerPC 750
            when 0x0a then :g4  # PowerPC 7400
            when 0x0b then :g4e # PowerPC 7450
            when 0x64 then :g5  # PowerPC 970
            else :dunno
          end
        else :dunno
      end
    end # model

    def extmodel; sysctl_int('machdep.cpu.extmodel'); end

    def cores; sysctl_int('hw.ncpu'); end

    def bits; @bits ||= sysctl_bool('hw.cpu64bit_capable') ? 64 : 32; end

    def is_32_bit?; bits == 32; end
    def is_64_bit?; bits == 64; end

    def _32b_arch
      case type
        when :intel   then :i386
        when :powerpc then :ppc
        else :dunno
      end
    end # _32b_arch
    # Backwards compatibility – existing usage is pervasive.
    alias_method :arch_32_bit, :_32b_arch

    def _64b_arch
      case type
        when :arm     then :arm64
        when :intel   then :x86_64
        when :powerpc then :ppc64
        else :dunno
      end
    end # _64b_arch
    # Backwards compatibility – existing usage is pervasive.
    alias_method :arch_64_bit, :_64b_arch

    # These return arrays extended with ArchitectureListExtension, which gives
    # helpers like #as_arch_flags and #as_cmake_arch_flags.  Note that building
    # 64-bit is barely possible and of questionable utility (and sanity) on
    # Tiger, and unevenly supported on Leopard.  Don't even try unless 64‐bit
    # builds are enabled, which they generally aren’t prior to Leopard.
    def all_32b_archs; [:i386, :ppc].extend ArchitectureListExtension; end
    def _64b_archs; [:ppc64, :x86_64].extend ArchitectureListExtension; end
    def _64b_archs_2; [:arm64, :x86_64].extend ArchitectureListExtension; end
    def all_64b_archs; [:arm64, :ppc64, :x86_64].extend ArchitectureListExtension; end
    def _4FB_archs; (all_32b_archs + _64b_archs).extend ArchitectureListExtension; end
    def all_archs; (all_32b_archs + all_64b_archs).extend ArchitectureListExtension; end
    def universal_archs
      ( if MacOS.version <= '10.5' and not MacOS.prefer_64_bit? then [_32b_arch]
        elsif MacOS.version >= '10.7' then [_64b_arch]
        else [_32b_arch, _64b_arch]; end
      ).extend ArchitectureListExtension
    end # universal_archs
    def cross_archs
      if MacOS.version <= '10.5' and MacOS.prefer_64_bit? then _4FB_archs
      elsif MacOS.version >= '11' then _64b_archs_2
      elsif MacOS.version >= '10.7' then [_64b_arch].extend ArchitectureListExtension
      elsif MacOS.version >= '10.4' then all_32b_archs
      else [:ppc]; end
    end # cross_archs

    def select_32b_archs(archlist)
      archlist.select { |arch|
          all_32b_archs.any? { |a32| a32 == arch }
        }.extend ArchitectureListExtension
    end

    def select_64b_archs(archlist)
      archlist.select { |arch|
          all_64b_archs.any? { |a64| a64 == arch }
        }.extend ArchitectureListExtension
    end

    # Determines whether the current CPU and macOS combination can run an
    # executable of the specified architecture.  “this” is an arch symbol.
    def can_run?(this)
      case type
        when :arm     then arm_can_run? this
        when :intel   then intel_can_run? this
        when :powerpc then powerpc_can_run? this
        else false
      end
    end # can_run?

    def features
      @features ||= sysctl_n(
        'machdep.cpu.features',
        'machdep.cpu.extfeatures',
        'machdep.cpu.leaf7_features'
      ).split(' ').map { |s| s.downcase.to_sym }
    end # features

    def feature?(name); features.include?(name); end

    def aes?; sysctl_bool('hw.optional.aes'); end

    def altivec?; sysctl_bool('hw.optional.altivec'); end

    def avx?; sysctl_bool('hw.optional.avx1_0'); end
    def avx2?; sysctl_bool('hw.optional.avx2_0'); end

    def sse3?; sysctl_bool('hw.optional.sse3'); end
    def ssse3?; sysctl_bool('hw.optional.supplementalsse3'); end
    def sse4?; sysctl_bool('hw.optional.sse4_1'); end
    def sse4_2?; sysctl_bool('hw.optional.sse4_2'); end

    private

    def sysctl_bool(key); sysctl_int(key) == 1; end

    def sysctl_int(key); sysctl_n(key).to_i; end

    def sysctl_n(*keys)
      (@properties ||= {}).fetch(keys) do
        @properties[keys] = Utils.popen_read('/usr/sbin/sysctl', '-n', *keys)
      end
    end

    def arm_can_run?(this)
      case this
        when :i386, :ppc, :ppc64 then false
        when :arm64, :x86_64     then true
        else false  # dunno
      end
    end # arm_can_run?

    def intel_can_run?(this)
      case this
        when :ppc           then MacOS.version < '10.7'  # Rosetta still available?
        when :arm64, :ppc64 then false  # No forward compatibility, & Rosetta never did PPC64
        when :x86_64        then Hardware::CPU.is_64_bit?
        when :i386          then MacOS.version <= '10.14'
        else false  # dunno
      end
    end # intel_can_run?

    def powerpc_can_run?(this)
      case this
        when :ppc then true
        when :ppc64 then Hardware::CPU.is_64_bit?
        else false  # No forwards compatibility
      end
    end # ppc_can_run?
  end # Hardware⸬CPU

  class << self
    def cores_as_words
      case Hardware::CPU.cores
        when 1 then 'single'
        when 2 then 'dual'
        when 4 then 'quad'
        else Hardware::CPU.cores
      end
    end # Hardware⸬cores_as_words

    def oldest_cpu(arch_type = Hardware::CPU.type)
      case arch_type
        when :intel   then :core
        when :powerpc then :g3
        else :dunno
      end
    end # Hardware⸬oldest_cpu

    def type_of(source)
      # source is either a specific model, or an architecture
      CPU.hw_type(source) or case source
                               when :ppc, :ppc64  then :powerpc
                               when :x86, :x86_64 then :intel
                               when :arm64        then :arm
                               else                    :dunno
                             end
    end # type_of
  end # << self
end # Hardware
