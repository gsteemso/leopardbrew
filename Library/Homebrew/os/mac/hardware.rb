# This file is loaded before `global.rb`, so must eschew many Homebrew‐isms at
# eval time.

require "mach"

module MacCPUs
  OPTIMIZATION_FLAGS = {
    :g3 => "-mcpu=750",
    :g4 => "-mcpu=7400",
    :g4e => "-mcpu=7450",
    :g5 => "-mcpu=970",
    :core => "-march=prescott",
    :core2 => "-march=core2",
    :penryn => "-march=core2 -msse4.1",
    :nehalem => "-march=core2 -msse4.2",
    :arrandale => "-march=core2 -msse4.2",
    :sandybridge => "-march=core2 -msse4.2",
    :ivybridge => "-march=core2 -msse4.2",
    :haswell => "-march=core2 -msse4.2",
    :broadwell => "-march=core2 -msse4.2"
  }.freeze
  def optimization_flags; OPTIMIZATION_FLAGS; end

  # These methods use info spewed out by sysctl.
  # Look in <mach/machine.h> for decoding info.
  def type
    case sysctl_int("hw.cputype")
      when  7 then :intel
      when 12 then :arm
      when 18 then :ppc
      else :dunno
    end
  end # type

  def arch
    case type
      when :arm   then :arm64
      when :intel then is_64_bit? ? :x86_64 : :i386
      when :ppc   then is_64_bit? ? :ppc64  : :ppc
    end
  end

  def model
    case type
      when :intel
        case sysctl_int("hw.cpufamily")
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
      when :ppc
        case sysctl_int("hw.cpusubtype")
          when 0x09 then :g3  # PowerPC 750
          when 0x0a then :g4  # PowerPC 7400
          when 0x0b then :g4e # PowerPC 7450
          when 0x64 then :g5  # PowerPC 970
          else :dunno
        end
      else :dunno
    end
  end # model

  def extmodel; sysctl_int("machdep.cpu.extmodel"); end

  def cores; sysctl_int("hw.ncpu"); end

  def bits; sysctl_bool("hw.cpu64bit_capable") ? 64 : 32; end

  def arch_32_bit
    case type
      when :intel then :i386
      when :ppc   then :ppc
      else :dunno
    end
  end # arch_32_bit

  def arch_64_bit
    case type
      when :arm   then :arm64
      when :intel then :x86_64
      when :ppc   then :ppc64
      else :dunno
    end
  end # arch_64_bit

  def archs_for_32b; [:i386, :ppc]; end

  def archs_for_64b; [:ppc64, :x86_64]; end

  def archs_2_for_64b; [:arm64, :x86_64]; end

  def preferred_arch
    MacOS.prefer_64_bit? ? Hardware::CPU.arch_64_bit : Hardware::CPU.arch_32_bit
  end

  def preferred_arch_as_list
    [preferred_arch].extend(ArchitectureListExtension)
  end

  # These return arrays that have been extended with ArchitectureListExtension,
  # which provides helpers like #as_arch_flags and #as_cmake_arch_flags.  Note
  # that building 64-bit is barely possible and probably unwise on Tiger, and
  # unevenly supported on Leopard.  Don't even try unless Leopardbrew's 64‐bit
  # support is enabled, which it isn’t prior to Leopard.

  def universal_archs
    if MacOS.version <= :leopard and not MacOS.prefer_64_bit?
      [arch_32_bit].extend ArchitectureListExtension
    elsif MacOS.version >= :lion
      [arch_64_bit].extend ArchitectureListExtension
    else
      [arch_32_bit, arch_64_bit].extend ArchitectureListExtension
    end
  end # universal_archs

  def cross_archs
    if MacOS.version <= :leopard and not MacOS.prefer_64_bit?
      archs_for_32b.extend ArchitectureListExtension
    elsif MacOS.version >= :big_sur
      archs_2_for_64b.extend ArchitectureListExtension
    elsif MacOS.version >= :lion
      archs_for_64b.extend ArchitectureListExtension
    else
      (archs_for_32b + archs_for_64b).extend ArchitectureListExtension
    end
  end # cross_archs

  # Determines whether the current CPU and macOS combination
  # can run an executable of the specified architecture.
  # “this” is a symbol in the same format returned by
  # #arch.
  def can_run?(this)
    case type
      when :arm   then arm_can_run? this
      when :intel then intel_can_run? this
      when :ppc   then ppc_can_run? this
      else false
    end
  end # can_run?

  def features
    @features ||= sysctl_n(
      "machdep.cpu.features",
      "machdep.cpu.extfeatures",
      "machdep.cpu.leaf7_features"
    ).split(" ").map { |s| s.downcase.to_sym }
  end # features

  def aes?; sysctl_bool("hw.optional.aes"); end

  def altivec?; sysctl_bool("hw.optional.altivec"); end

  def avx?; sysctl_bool("hw.optional.avx1_0"); end

  def avx2?; sysctl_bool("hw.optional.avx2_0"); end

  def sse3?; sysctl_bool("hw.optional.sse3"); end

  def ssse3?; sysctl_bool("hw.optional.supplementalsse3"); end

  def sse4?; sysctl_bool("hw.optional.sse4_1"); end

  def sse4_2?; sysctl_bool("hw.optional.sse4_2"); end

  private

  def sysctl_bool(key); sysctl_int(key) == 1; end

  def sysctl_int(key); sysctl_n(key).to_i; end

  def sysctl_n(*keys)
    (@properties ||= {}).fetch(keys) do
      @properties[keys] = Utils.popen_read("/usr/sbin/sysctl", "-n", *keys)
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
      when :ppc           then MacOS.version < :lion  # Rosetta is still available
      when :arm64, :ppc64 then false  # No forwards compatibility, and Rosetta never did PPC64
      when :x86_64        then Hardware::CPU.is_64_bit?
      when :i386          then MacOS.version <= :mojave
      else false  # dunno
    end
  end # intel_can_run?

  def ppc_can_run?(this)
    case this
      when :ppc then true
      when :ppc64 then Hardware::CPU.is_64_bit?
      else false  # No forwards compatibility
    end
  end # ppc_can_run?
end # MacCPUs
