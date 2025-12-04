# This file is loaded before `global.rb`, so must eschew many brew‐isms at eval time.
require 'mach'

class CPU
  module Sysctl
    # All of the following use data extracted via sysctl.  See <sys/sysctl.h> for sysctl keys, as well as some related constants, &
    # <mach/machine.h> for Mach‐O CPU‐encoding constants.

    module_function

    def type
      @@type ||= case sysctl_int('hw.cputype')  # Always has flags masked out, including 64-bitness.
                   when  7 then :intel
                   when 12 then :arm
                   when 18 then :powerpc
                   else :dunno
                 end
    end # CPU⸬Sysctl⸬type

    def model
      @@model ||= \
        case type
          when :arm, :intel
            case sysctl_int('hw.cpufamily')
              when 0x07d34b9f then :a12z        # arm    0. (Aruba?) developer‐transition Minis (Vortex & Tempest cores)
              when 0x0f817246 then :kabylake    # intel 10. Kaby Lake
              when 0x10b282dc then :haswell     # intel  7. Haswell
              when 0x1b588bb3 then :m1          # arm    1. A14/M1, most variants (Firestorm & Icestorm cores)
              when 0x1cf8a03e then :cometlake   # intel 12. Comet Lake
              when 0x1f65e835 then :ivybridge   # intel  6. Ivy Bridge
              when 0x204526d0 then :m4          # arm    8. Tupai (probably m4?)
              when 0x2876f5b5 then :m3          # arm    ?. Coll (probably m3?)
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
              when 0x75d4acb9 then :m4          # arm    7. Tahiti (probably m4?)
              when 0x78ea4fbc then :penryn      # intel  2. Penryn  (E8x35, P7x50, P8x00, SL9x00, SU9x00, T8x00, T9x00, T9550)
              when 0xda33d83d then :m2          # arm    2. A15/M2, most variants (Avalanche & Blizzard cores)
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
        end # case type
    end # CPU⸬Sysctl⸬model

    def cores; sysctl_int('hw.physicalcpu_max'); end

    def extmodel; sysctl_int('machdep.cpu.extmodel'); end

    def features
      @@features ||= sysctl_n(
          'machdep.cpu.features',
          'machdep.cpu.extfeatures',
          'machdep.cpu.leaf7_features'
        ).split(' ').map { |s| s.downcase.to_sym }
    end # CPU⸬Sysctl⸬features

    def _64b?; @@_64b ||= sysctl_bool('hw.cpu64bit_capable'); end

    def aes?; sysctl_bool('hw.optional.aes'); end

    def altivec?; sysctl_bool('hw.optional.altivec'); end

    def avx?; sysctl_bool('hw.optional.avx1_0'); end
    def avx2?; sysctl_bool('hw.optional.avx2_0'); end

    def sse3?; sysctl_bool('hw.optional.sse3'); end
    def ssse3?; sysctl_bool('hw.optional.supplementalsse3'); end
    def sse4?; sysctl_bool('hw.optional.sse4_1'); end
    def sse4_2?; sysctl_bool('hw.optional.sse4_2'); end

    private

    module_function

    def sysctl_bool(key); sysctl_int(key) == 1; end

    def sysctl_int(key); sysctl_n(key).to_i; end

    def sysctl_n(*keys)
      (@@properties ||= {}).fetch(keys) do
        @@properties[keys] = Utils.popen_read('/usr/sbin/sysctl', '-n', *keys)
      end
    end
  end # Sysctl

  class << self
    include ArchitectureConstants

    def type;     Sysctl.type;     end
    def model;    Sysctl.model;    end
    def cores;    Sysctl.cores;    end
    def extmodel; Sysctl.extmodel; end
    def features; Sysctl.features; end
    def _64b?;    Sysctl._64b?;    end
    def aes?;     Sysctl.aes?;     end
    def altivec?; Sysctl.altivec?; end
    def avx?;     Sysctl.avx?;     end
    def avx2?;    Sysctl.avx2?;    end
    def sse3?;    Sysctl.sse3?;    end
    def ssse3?;   Sysctl.ssse3?;   end
    def sse4?;    Sysctl.sse4?;    end
    def sse4_2?;  Sysctl.sse4_2?;  end

    TYPE_DATA = {
      :powerpc => {:archs => POWERPC_ARCHS},
      :intel   => {:archs => INTEL_ARCHS  },
      :arm     => {:archs => ARM_ARCHS    },
    }.freeze

    ARCH_DATA = {
      :ppc     => {:bits => 32, :type => :powerpc, :oldest => (Sysctl.model == :g3 ? :g3 : :g4)},  # Allow Altivec unless we _can’t_.
      :ppc64   => {:bits => 64, :type => :powerpc, :oldest => :g5},
      :i386    => {:bits => 32, :type => :intel,   :oldest => :core},
      :x86_64  => {:bits => 64, :type => :intel,   :oldest => :core2},
      :x86_64h => {:bits => 64, :type => :intel,   :oldest => :haswell},
      :arm64   => {:bits => 64, :type => :arm,     :oldest => :a12z},
      :arm64e  => {:bits => 64, :type => :arm,     :oldest => :m1},
    }.freeze

    # TODO:  Properly account for optflags under Clang
    MODEL_DATA = {
      :g3          => {:bits => 32, :type => :powerpc, :arch => :ppc,     :oldest => :g3,      :gcc => {:vrsn =>  4.0, :flags => '-mcpu=750'            }, :clang => {:vrsn => nil, :flags => '-mcpu=750'            },},
      :g4          => {:bits => 32, :type => :powerpc, :arch => :ppc,     :oldest => :g4,      :gcc => {:vrsn =>  4.0, :flags => '-mcpu=7400'           }, :clang => {:vrsn => nil, :flags => '-mcpu=7400'           },},
      :g4e         => {:bits => 32, :type => :powerpc, :arch => :ppc,     :oldest => :g4e,     :gcc => {:vrsn =>  4.0, :flags => '-mcpu=7450'           }, :clang => {:vrsn => nil, :flags => '-mcpu=7450'           },},
      :g5          => {:bits => 64, :type => :powerpc, :arch => :ppc64,   :oldest => :g5,      :gcc => {:vrsn =>  4.0, :flags => '-mcpu=970'            }, :clang => {:vrsn => nil, :flags => '-mcpu=970'            },},
      :core        => {:bits => 32, :type => :intel,   :arch => :i386,    :oldest => :core,    :gcc => {:vrsn =>  4.0, :flags => '-march=prescott'      }, :clang => {:vrsn => nil, :flags => '-march=prescott'      },},
      :core2       => {:bits => 64, :type => :intel,   :arch => :x86_64,  :oldest => :core2,   :gcc => {:vrsn =>  4.2, :flags => '-march=core2'         }, :clang => {:vrsn => nil, :flags => '-march=core2'         },},
      :penryn      => {:bits => 64, :type => :intel,   :arch => :x86_64,  :oldest => :core2,   :gcc => {:vrsn =>  4.2, :flags => '-march=core2 -msse4.1'}, :clang => {:vrsn => nil, :flags => '-march=core2 -msse4.1'},},
      :nehalem     => {:bits => 64, :type => :intel,   :arch => :x86_64,  :oldest => :core2,   :gcc => {:vrsn =>  4.9, :flags => '-march=nehalem'       }, :clang => {:vrsn => nil, :flags => '-march=nehalem'       },},
      :arrandale   => {:bits => 64, :type => :intel,   :arch => :x86_64,  :oldest => :core2,   :gcc => {:vrsn =>  4.9, :flags => '-march=westmere'      }, :clang => {:vrsn => nil, :flags => '-march=westmere'      },},
      :sandybridge => {:bits => 64, :type => :intel,   :arch => :x86_64,  :oldest => :core2,   :gcc => {:vrsn =>  4.9, :flags => '-march=sandybridge'   }, :clang => {:vrsn => nil, :flags => '-march=sandybridge'   },},
      :ivybridge   => {:bits => 64, :type => :intel,   :arch => :x86_64,  :oldest => :core2,   :gcc => {:vrsn =>  4.9, :flags => '-march=ivybridge'     }, :clang => {:vrsn => nil, :flags => '-march=ivybridge'     },},
      :haswell     => {:bits => 64, :type => :intel,   :arch => :x86_64h, :oldest => :haswell, :gcc => {:vrsn =>  4.9, :flags => '-march=haswell'       }, :clang => {:vrsn => nil, :flags => '-march=haswell'       },},
      :broadwell   => {:bits => 64, :type => :intel,   :arch => :x86_64h, :oldest => :haswell, :gcc => {:vrsn =>  4.9, :flags => '-march=broadwell'     }, :clang => {:vrsn => nil, :flags => '-march=broadwell'     },},
      :skylake     => {:bits => 64, :type => :intel,   :arch => :x86_64h, :oldest => :haswell, :gcc => {:vrsn =>  6,   :flags => '-march=skylake'       }, :clang => {:vrsn => nil, :flags => '-march=skylake'       },},
      :kabylake    => {:bits => 64, :type => :intel,   :arch => :x86_64h, :oldest => :haswell, :gcc => {:vrsn =>  6,   :flags => '-march=skylake'       }, :clang => {:vrsn => nil, :flags => '-march=skylake'       },},
      :icelake     => {:bits => 64, :type => :intel,   :arch => :x86_64h, :oldest => :haswell, :gcc => {:vrsn =>  8,   :flags => '-march=icelake-client'}, :clang => {:vrsn => nil, :flags => '-march=icelake-client'},},
      :cometlake   => {:bits => 64, :type => :intel,   :arch => :x86_64h, :oldest => :haswell, :gcc => {:vrsn =>  6,   :flags => '-march=skylake'       }, :clang => {:vrsn => nil, :flags => '-march=skylake'       },},
      :a12z        => {:bits => 64, :type => :arm,     :arch => :arm64,   :oldest => :a12z,    :gcc => {:vrsn => 15,   :flags => '-mcpu=apple-m1'       }, :clang => {:vrsn => nil, :flags => '-mcpu=apple-m1'       },},
      :m1          => {:bits => 64, :type => :arm,     :arch => :arm64e,  :oldest => :m1,      :gcc => {:vrsn => 15,   :flags => '-mcpu=apple-m1'       }, :clang => {:vrsn => nil, :flags => '-mcpu=apple-m1'       },},
      :m2          => {:bits => 64, :type => :arm,     :arch => :arm64e,  :oldest => :m1,      :gcc => {:vrsn => 15,   :flags => '-mcpu=apple-m2'       }, :clang => {:vrsn => nil, :flags => '-mcpu=apple-m2'       },},
      :m3          => {:bits => 64, :type => :arm,     :arch => :arm64e,  :oldest => :m1,      :gcc => {:vrsn => 15,   :flags => '-mcpu=apple-m3'       }, :clang => {:vrsn => nil, :flags => '-mcpu=apple-m3'       },},
      :m4          => {:bits => 64, :type => :arm,     :arch => :arm64e,  :oldest => :m1,      :gcc => {:vrsn => 15,   :flags => '-mcpu=apple-m3'       }, :clang => {:vrsn => nil, :flags => '-mcpu=apple-m3'       },},
    }.freeze

    # What flags do you use when your CPU is newer than your compiler knows about?
    # TODO:  Make a similar routine for Clang.
    def gcc_flags_for_post_(v, t = type)
      case t
        when :intel
          if    v < 4.2 then '-march=nocona -mssse3'
          elsif v < 4.9 then '-march=core2 -msse4.2'
          elsif v <  5  then '-march=broadwell'
          elsif v <  6  then '-march=broadwell -mclflushopt -mxsavec -mxsaves'
          elsif v <  8  then '-march=skylake-avx512 -mavx512ifma -mavx512vbmi -msha'
          else ''; end
        else ''
      end
    end # CPU⸬gcc_flags_for_post_

    def type_data(t = type); TYPE_DATA.fetch(t); end

    def arch_data(a = arch); ARCH_DATA.fetch(a); end

    def model_data(m = model); MODEL_DATA.fetch(m); end

    def known_types; TYPE_DATA.keys; end

    CPU.known_types().each{ |t| define_method("#{t}?") { type == t } }

    def known_archs; ARCH_DATA.keys.extend ArchitectureListExtension; end

    def known_models; MODEL_DATA.keys; end

    def archs_of_type(t = type); (type_data(t)[:archs]).extend ArchitectureListExtension; end

    def which_gcc_knows_about(m = model); model_data(m)[:gcc][:vrsn] if model_data(m); end

    def type_of(obj)
      case obj
        when *known_types         then obj
        when *known_archs         then arch_data(obj)[:type]
        when *known_models        then model_data(obj)[:type]
        when :altivec,  :g5_64    then :powerpc
        when :intel_32, :intel_64 then :intel
      end  # Return nil for any other input.
    end # CPU⸬type_of

    def arch_of(obj)
      case obj
        when *known_types  then archs_of_type(obj).first
        when *known_archs  then obj
        when *known_models then model_data(obj)[:arch]
        when :altivec      then :ppc
        when :g5_64        then :ppc64
        when :intel_32     then :i386
        when :intel_64     then :x86_64
      end  # Return nil for any other input.
    end # CPU⸬arch_of

    def native_archs
      o = model_data[:oldest]
      archs_of_type.reject{ |a| case a
          when :arm64   then o == :m1
          when :arm64e  then o == :a12z
          when :x86_64  then o == :haswell
          when :x86_64h then o == :core2
          else false
        end # case a
      }.extend ArchitectureListExtension
    end # CPU⸬native_archs

    def cores_as_words
      case cores
        when 1 then 'single'
        when 2 then 'dual'
        when 4 then 'quad'
        when 6 then 'hex'
        else cores
      end
    end # CPU⸬cores_as_words

    def feature?(name); features.include?(name); end

    def bits; _64b? ? 64 : 32; end

    def _32b?; not _64b?; end

    # Can the current CPU and Mac OS combination can run an executable of “this” architecture?
    def can_run?(this)
      case type
        when :arm     then arm_can_run? this
        when :intel   then intel_can_run? this
        when :powerpc then powerpc_can_run? this
        else false
      end
    end # CPU⸬can_run?

    private

    def arm_can_run?(this)
      case this
        when :arm64, :x86_64, :x86_64h then true
        when :arm64e                   then model_data[:oldest] == :m1
        else false  # :i386, :ppc, :ppc64, :dunno
      end
    end # CPU⸬arm_can_run?

    def intel_can_run?(this)
      case this
        when :arm64, :arm64e, :ppc64 then false  # No fwd compatibility, & Rosetta never did PPC64.
        when :ppc                    then MacOS.version < :lion  # Rosetta still available?
        when :i386                   then MacOS.version < :catalina
        when :x86_64                 then _64b?
        when :x86_64h                then model_data[:oldest] == :haswell
        else false  # :dunno
      end
    end # CPU⸬intel_can_run?

    def powerpc_can_run?(this)
      case this
        when :ppc   then true
        when :ppc64 then _64b? and MacOS.version >= :tiger
        else false  # No forwards compatibility.
      end
    end # CPU⸬ppc_can_run?
  end # << self
end # CPU
