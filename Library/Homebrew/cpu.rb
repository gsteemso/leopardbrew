# This file is loaded before `global.rb`, so must eschew many Homebrew‐isms at
# eval time.

require 'mach'

class CPU
  class << self
    KNOWN_ARCHS = {
      :powerpc => [:ppc, :ppc64],
      :intel   => [:i386, :x86_64,  :x86_64h],
      :arm     => [:arm64, :arm64e],
    }.freeze

    # TODO:  Properly account for optflags under Clang
    MODEL_FLAGS = { # bits  type      arch    btl. mdl.  GCC?    GCC optflags
      :g3          => [32, :powerpc, :ppc,     :g3,      4.0,   '-mcpu=750'],
      :g4          => [32, :powerpc, :ppc,     :g4,      4.0,   '-mcpu=7400'],
      :g4e         => [32, :powerpc, :ppc,     :g4e,     4.0,   '-mcpu=7450'],
      :g5          => [64, :powerpc, :ppc64,   :g5,      4.0,   '-mcpu=970'],
      :core        => [32, :intel,   :i386,    :core,    4.0,   '-march=prescott'],
      :core2       => [64, :intel,   :x86_64,  :core2,   4.2,   '-march=core2'],
      :penryn      => [64, :intel,   :x86_64,  :core2,   4.2,   '-march=core2 -msse4.1'],
      :nehalem     => [64, :intel,   :x86_64,  :core2,   4.9,   '-march=nehalem'],
      :arrandale   => [64, :intel,   :x86_64,  :core2,   4.9,   '-march=westmere'],
      :sandybridge => [64, :intel,   :x86_64,  :core2,   4.9,   '-march=sandybridge'],
      :ivybridge   => [64, :intel,   :x86_64,  :core2,   4.9,   '-march=ivybridge'],
      :haswell     => [64, :intel,   :x86_64h, :haswell, 4.9,   '-march=haswell'], # h → Haswell
      :broadwell   => [64, :intel,   :x86_64h, :haswell, 4.9,   '-march=broadwell'],
      :skylake     => [64, :intel,   :x86_64h, :haswell, 6,     '-march=skylake'],
      :kabylake    => [64, :intel,   :x86_64h, :haswell, 6,     '-march=skylake'],
      :icelake     => [64, :intel,   :x86_64h, :haswell, 8,     '-march=icelake-client'],
      :cometlake   => [64, :intel,   :x86_64h, :haswell, 6,     '-march=skylake'],
      :a12z        => [64, :arm,     :arm64e,  :m1,      false, ''],  # e → Apple silicon
      :m1          => [64, :arm,     :arm64e,  :m1,      false, ''],
      :m2          => [64, :arm,     :arm64e,  :m1,      false, ''],
      :m3          => [64, :arm,     :arm64e,  :m1,      false, ''],
      :m4          => [64, :arm,     :arm64e,  :m1,      false, ''],
    }.freeze

    def known_archs; KNOWN_ARCHS.values.flatten; end

    def known_models; MODEL_FLAGS.keys; end

    def bit_width(m = model); MODEL_FLAGS[m][0] if MODEL_FLAGS[m]; end

    def hw_type(m = model); MODEL_FLAGS[m][1] if MODEL_FLAGS[m]; end

    def arch(m = model); MODEL_FLAGS[m][2] if MODEL_FLAGS[m]; end

    def bottle_target_for(m = model); MODEL_FLAGS[m][3] if MODEL_FLAGS[m];end

    def which_gcc_knows_about(m = model); MODEL_FLAGS[m][4] if MODEL_FLAGS[m]; end

    def gcc_intel_flags_for_post_(v)
      if v < 4.2 then '-march=nocona -mssse3'
      elsif v < 4.9 then '-march=core2 -msse4.2'
      elsif v < 5 then '-march=broadwell'
      elsif v < 6 then '-march=broadwell -mclflushopt -mxsavec -mxsaves'
      elsif v < 8 then '-march=skylake-avx512 -mavx512ifma -mavx512vbmi -msha'
      else ''; end
    end # gcc_intel_flags_for_post_

    def gcc_arm_flags_for_post_(v); ''; end

    def optimization_flags(m = model, gcc_version = 4.2)
      return '' unless MODEL_FLAGS[m]
      if (vers = which_gcc_knows_about(m))
        if gcc_version >= vers
          MODEL_FLAGS[m][5]
        else case hw_type(m)
            when :intel then gcc_intel_flags_for_post_(gcc_version)
            when :arm   then gcc_arm_flags_for_post_(gcc_version)
            else ''
          end
        end
      else ''; end
    end # optimization_flags

    def opt_flags_as_map(gcc_version = 4.2)
      hsh = {}
      known_models.each{ |m| hsh[m] = optimization_flags(m, gcc_version) }
      hsh
    end

    def oldest(arch_type = type)
      case arch_type
        when :altivec              then :g4
        when :arm, :arm64, :arm64e then :m1
        when :i386, :intel         then :core
        when :powerpc, :ppc        then :g3
        when :ppc64                then :g5
        when :x86_64               then :core2
        when :x86_64h              then :haswell
        else :dunno
      end
    end # CPU⸬oldest

  # Many of the following use things spewed out by sysctl.  See <sys/sysctl.h>
  # for sysctl keys along with some related constants, and <mach/machine.h> for
  # constants associated with Mach‐O CPU encoding.

    def type
      @type ||= case sysctl_int('hw.cputype')  # always has flags masked out, including 64-bitness
                  when  7 then :intel
                  when 12 then :arm
                  when 18 then :powerpc
                  else :dunno
                end
    end # CPU⸬type

    KNOWN_TYPES = [:powerpc, :intel, :arm].freeze

    KNOWN_TYPES.each { |t| define_method("#{t}?") { type == t } }

    def model
      case type
        when :arm, :intel
          case sysctl_int('hw.cpufamily')
            when 0x07d34b9f then :a12z        # arm    0. (Aruba?) developer‐transition Minis (Vortex & Tempest cores)
            when 0x0f817246 then :kabylake    # intel 10. Kaby Lake
            when 0x10b282dc then :haswell     # intel  7. Haswell
            when 0x1b588bb3 then :m1          # arm    1. A14/M1, all variants (Firestorm & Icestorm cores)
            when 0x1cf8a03e then :cometlake   # intel 12. Comet Lake
            when 0x1f65e835 then :ivybridge   # intel  6. Ivy Bridge
            when 0x37fc219f then :skylake     # intel  9. Sky Lake
            when 0x38435547 then :icelake     # intel 11. Ice Lake
            when 0x426f69ef then :core2       # intel  1. Merom et al:  Core 2 Duo  (Ex600, P7x00, T5600, T7x00, X7900)
            when 0x5490b78c then :sandybridge # intel  5. Sandy Bridge
            when 0x573b5eec then :arrandale   # intel  4. Arrandale (on Wikipedia see under “Westmere”)
            when 0x582ed09c then :broadwell   # intel  8. Broadwell
            when 0x5f4dea93 then :m3          # arm    4. Lobos (M3 Pro:  Everest & Sawtooth cores)
            when 0x6b5a4cd2 then :nehalem     # intel  3. Nehalem
            when 0x6f5129ac then :m4          # arm    6. Donan
            when 0x72015832 then :m3          # arm    5. Palma (M3 Max:  Everest & Sawtooth cores)
            when 0x73d67300 then :core        # intel  0. Yonah et al:  Core Solo/Duo  (T1200, T2x00, L2400)
            when 0x78ea4fbc then :penryn      # intel  2. Penryn  (E8x35, P7x50, P8x00, SL9x00, SU9x00, T8x00, T9x00, T9550)
            when 0xda33d83d then :m2          # arm    2. A15/M2, all variants (Avalanche & Blizzard cores)
            when 0xfa33415e then :m3          # arm    3. Ibiza (base M3:  Everest & Sawtooth cores)
            else type == :arm ? :m1 : :core
          end
        when :powerpc
          case sysctl_int('hw.cpusubtype')  # always has flags masked out
            when 0x09 then :g3  # powerpc 0. PPC 750
            when 0x0a then :g4  # powerpc 1. PPC 7400
            when 0x0b then :g4e # powerpc 2. PPC 7450
            when 0x64 then :g5  # powerpc 3. PPC 970
            else :g3
          end
        else :dunno
      end
    end # CPU⸬model

    def type_of(source)
      # source is either a specific model, or an architecture
      hw_type(source) || case source
          when :altivec, :ppc, :ppc64
            :powerpc
          when :i386, :x86_64, :x86_64h
            :intel
          when :arm64, :arm64e
            :arm
          else :dunno
        end
    end # CPU⸬type_of

    def cores; sysctl_int('hw.physicalcpu_max'); end

    def cores_as_words
      case cores
        when 1 then 'single'
        when 2 then 'dual'
        when 4 then 'quad'
        when 6 then 'hex'
        else cores
      end
    end # CPU⸬cores_as_words

    def bits; _64b? ? 64 : 32; end

    def _32b?; not _64b?; end
    def _64b?; @_64b ||= sysctl_bool('hw.cpu64bit_capable'); end

    def _32b_arch
      case type
        when :intel   then :i386
        when :powerpc then :ppc
        else :dunno
      end
    end # CPU⸬_32b_arch

    def _64b_arch
      case type
        when :arm     then :arm64e
        when :intel   then :x86_64  # the more compatible option
        when :powerpc then :ppc64
        else :dunno
      end
    end # CPU⸬_64b_arch

    # These return arrays extended with ArchitectureListExtension, which gives
    # helpers like #as_arch_flags and #as_cmake_arch_flags.  Note that building
    # 64-bit is barely possible and of questionable utility (and sanity) on
    # Tiger, and unevenly supported on Leopard.  Don't even try unless 64‐bit
    # builds are enabled, which they generally aren’t prior to Leopard.
    def all_32b_archs; [:i386, :ppc].extend ArchitectureListExtension; end
    def _64b_archs_1; [:ppc64, :x86_64].extend ArchitectureListExtension; end
    def _64b_archs_2; [:arm64e, :x86_64h].extend ArchitectureListExtension; end
    def all_64b_archs; [:arm64e, :ppc64, :x86_64, :x86_64h].extend ArchitectureListExtension; end
    def quad_fat_archs; (all_32b_archs + _64b_archs_1).extend ArchitectureListExtension; end
    def all_archs; (all_32b_archs + all_64b_archs).extend ArchitectureListExtension; end
    def local_archs
      ( if MacOS.version <= '10.5' and not MacOS.prefer_64_bit? then [_32b_arch]
        elsif MacOS.version >= '10.7' then [_64b_arch]
        else [_32b_arch, _64b_arch]; end
      ).extend ArchitectureListExtension
    end # CPU⸬local_archs
    def cross_archs
      if MacOS.version <= '10.5' and MacOS.prefer_64_bit? then quad_fat_archs
      elsif MacOS.version >= '11' then _64b_archs_2
      elsif MacOS.version >= '10.7' then [_64b_arch].extend ArchitectureListExtension
      elsif MacOS.version >= '10.4' then all_32b_archs
      else [:ppc].extend ArchitectureListExtension
      end
    end # CPU⸬cross_archs
    def runnable_archs; all_archs.select{ |a| can_run?(a) }.extend ArchitectureListExtension; end;

    def select_32b_archs(archlist)
      archlist.select{ |a| is_32b_arch?(a) }.extend ArchitectureListExtension
    end

    def select_64b_archs(archlist)
      archlist.select{ |a| is_64b_arch?(a) }.extend ArchitectureListExtension
    end

    def is_32b_arch?(a); all_32b_archs.any?{ |a32| a == a32 }; end

    def is_64b_arch?(a); not is_32b_arch?(a); end

    def bottle_target_model
      case (barch = ARGV.bottle_arch || model)
        when :altivec              then :g4
        when :arm, :arm64, :arm64e then :m1
        when :g5_64, :ppc64        then :g5
        when :i386                 then :core
        when :intel                then MacOS.prefer_64_bit? ? :core2 : :core
        when :powerpc              then MacOS.prefer_64_bit? ? :g5    : :g3
        when :ppc                  then :g3
        when :x86_64               then :core2
        when :x86_64h              then :haswell
        else bottle_target_for(barch) or
               raise ArgumentError, 'The requested bottle architecture was not recognized.'
      end
    end # bottle_target_model

    def bottle_target_arch
      case (barch = ARGV.bottle_arch || arch)
        when :altivec     then :ppc
        when :arm, :arm64 then :arm64e
        when :arm64e, :i386, :ppc, :ppc64, :x86_64, :x86_64h then barch
        when :g5_64       then :ppc64
        when :intel       then MacOS.prefer_64_bit? ? :x86_64 : :i386
        when :powerpc     then MacOS.prefer_64_bit? ? :ppc64  : :ppc
        else arch(barch) or
               raise ArgumentError, 'The requested bottle architecture was not recognized.'
      end
    end # bottle_target_arch

    # Determines whether the current CPU and Mac OS combination can run an
    # executable of the specified architecture.  “this” is an arch symbol.
    def can_run?(this)
      case type
        when :arm     then arm_can_run? this
        when :intel   then intel_can_run? this
        when :powerpc then powerpc_can_run? this
        else false
      end
    end # CPU⸬can_run?

    def extmodel; sysctl_int('machdep.cpu.extmodel'); end

    def features
      @features ||= sysctl_n(
          'machdep.cpu.features',
          'machdep.cpu.extfeatures',
          'machdep.cpu.leaf7_features'
        ).split(' ').map { |s| s.downcase.to_sym }
    end # CPU⸬features

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
        when :i386, :ppc, :ppc64                then false
        when :arm64, :arm64e, :x86_64, :x86_64h then true
        else false  # dunno
      end
    end # CPU⸬arm_can_run?

    def intel_can_run?(this)
      case this
        when :arm64, :arm64e, :ppc64 then false  # No forward compatibility, & Rosetta never did PPC64
        when :ppc                    then MacOS.version < '10.7'  # Rosetta still available?
        when :i386                   then MacOS.version <= '10.14'
        when :x86_64                 then _64b?
        when :x86_64h                then bottle_target_for == :haswell
        else false  # dunno
      end
    end # CPU⸬intel_can_run?

    def powerpc_can_run?(this)
      case this
        when :ppc   then true
        when :ppc64 then _64b? and MacOS.version >= '10.5'
        else false  # No forwards compatibility
      end
    end # CPU⸬ppc_can_run?
  end # << self
end # CPU
