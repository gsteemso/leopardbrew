# This library is loaded before ENV gets extended.
require 'macos'  # pulls in cpu for us

class Target
  class << self
    def allow_universal_binary; @@formula_can_be_universal = true;  end
    def no_universal_binary;    @@formula_can_be_universal = false; end

    # This is only used on request.  Some formulæ can only be built for specific architectures.  When an ArchitectureRequirement is
    # depended upon, it uses this method; then, ⸬filter_archs forcibly restricts the built architectures to those which the formula
    # can handle.
    def restrict_archset(allowed);
      @permissible_archs = if allowed then allowed.flat_map{ |a|
          CPU.known_types.include?(a) ? CPU.archs_of_type(a) : CPU.arch_of(a)
        }.uniq; end
    end

    def filter_archs(archset); @permissible_archs ? archset.select{ |a| @permissible_archs.include?(a) } : archset; end

    def die_from_filter(tried)
      odie 'No CPU architectures are valid build targets!', <<-_.undent.rewrap
          The CPU architectures which may currently be built for are [#{@permissible_archs.list}],
          but the current settings will only attempt building for [#{tried.list}].
        _
    end # Target⸬die_from_filter

    # What architecture are we building for?  Either one passed explicitly through --bottle-arch=, or the preferred variant for our
    # native hardware.  We do not care if a bottle will be built, only if an architecture for one was supplied.
    # This routine assumes that only the specified or preferred architecture will be built.  To process multiple architectures, use
    # Target⸬archset().
    def arch
      @arch ||= (ARGV.bottle_arch ? CPU.arch_of(ARGV.bottle_arch) : preferred_arch)
      if @permissible_archs and not @permissible_archs.include?(@arch) then die_from_filter([@arch]); end
      @arch
    end

    # What set of architectures are we building for?  Either a declared bottle architecture, or a preferred native architecture.  A
    # universal build includes every runnable architecture (with less‐capable duplicates, such as bare :x86_64 on a Haswell machine,
    # removed).  A “cross” build includes every buildable architecture (with, again, less‐capable duplicates removed).
    def archset
      desired_archset = (@@formula_can_be_universal and ARGV.build_fat?) ? (ARGV.build_cross? ? cross_archs : local_archs) \
                                                : (a = ARGV.bottle_arch) ? [oldest(a)].extend(ArchitectureListExtension) \
                                                : preferred_arch_as_list
      result = filter_archs desired_archset
      die_from_filter(desired_archset) if result.empty?
      result
    end # Target⸬archset

    # What CPU type are we building for?  Either one corresponding to a value explicitly passed using --bottle-arch=, or our native
    # one.  We do not care if a bottle will be built, only whether an architecture for one was supplied.
    # This routine assumes that only the specified or preferred CPU type will be built for.  To accommodate multiple CPU types, use
    # Target⸬typeset() with specific architectures and/or models.
    def type; @type ||= (ARGV.bottle_arch ? CPU.type_of(ARGV.bottle_arch) : CPU.type); end

    def typeset(as = archset); as.map(&CPU.type_of).uniq; end

    def model_for_arch(a); (CPU.type_of(a) == CPU.type) ? CPU.model : oldest(a); end

    def modelset(as = archset); as.map(&:model_for_arch).uniq; end

    # What CPU model are we building for?  Either one passed via --bottle-arch=, or the native one.  We don’t care if a bottle will
    # be built, only if an architecture for one was supplied.
    # This routine assumes that only the specified or preferred CPU model will be built for.  To handle multiple CPU models implies
    # multiple architectures, as Mac OS policy forbids coëxistent subarchitectures, and thus the use of Target⸬model_for_arch().
    def model
      # On an x86 CPU without SSE4, neither “-march=native” nor “-march=#{model}” can be trusted, as we might be running in a VM or
      # on a Hackintosh.
      @model ||= (ARGV.bottle_arch ? oldest(ARGV.bottle_arch) : (CPU.intel? and not CPU.sse4?) ? oldest(CPU.model) : CPU.model)
    end # Target⸬model

    # Get the least‐common‐denominator (i.e., the oldest) CPU model that shares characteristics with the parameter – a specific CPU
    # model, an architecture, a CPU type, or a bottle‐supporting tag.
    def oldest(obj = (CPU._64b? ? _64b_arch : _32b_arch))
      CPU.known_models.include?(obj) ? CPU.model_data(obj)[:oldest] \
        : CPU.known_archs.include?(obj) ? CPU.arch_data(obj)[:oldest] \
        : CPU.known_types.include?(obj) ? CPU.arch_data(CPU.archs_of_type(obj).first)[:oldest] \
        : case obj
            when :altivec  then :g4
            when :g5_64    then :g5
            when :intel_32 then :core
            when :intel_64 then :core2
          end  # Return nil for any other input.
    end # Target⸬oldest

    def model_optflags(m = model)
      ( if CPU.model_data(m)
          if ENV.compiler != :clang # assume is some variant of GCC
            if (vers = CPU.which_gcc_knows_about(m))
              (ENV.compiler_version >= vers ? CPU.model_data(m)[:gcc][:flags] \
                                            : CPU.gcc_flags_for_post_(gcc_version, CPU.type_of(m)))
            end
          end
        end
      ) || (
        case CPU.type_of(m)
#         when :arm     then ???
          when :intel   then (bits(m) == 64 ? '-march=nocona'   : '-march=i386')
          when :powerpc then (bits(m) == 64 ? '-mcpu=powerpc64' : '-mcpu=powerpc')
          else ''
        end
      )
    end # Target⸬model_optflags

    def model_optflag_map; h = {}; CPU.known_models.each{ |m| h[m] = model_optflags(m) }; h; end

    # This gets the optimization flags for each one model being built for, and makes them architecture-specific using -Xarch_<arch>.
    # This only works with :gcc, :llvm, or :clang, though work is in progress to enable it for the FSF GCCs as well.  That said, it
    # is not supported at all by any GCC prior to 4.2, whether Apple or FSF.
    def optimization_flagset(as = archset)
      if as.length > 1 and ENV.compiler != :gcc_4_0
        fs = []
        as.each{ |a| fs << model_optflags(model_for_arch(a)).split(' ').map{ |f| "-Xarch_#{a} #{f}" } }
        fs * ' '
      else
        model_optflags(model_for_arch(as.first))
      end
    end

    def prefer_64b?
      @_64b_checked ||= nil
      unless @_64b_checked
        @_64b_checked = true
        @prefer_64b ||= (CPU._64b? and (MacOS.version >= :snow_leopard or
                                         (MacOS.version >= :leopard and envflag = ENV['HOMEBREW_PREFER_64_BIT'].choke) or
                                         (MacOS.version >= :tiger and envflag and envflag.downcase == 'force')
                        )              )
      end
      @prefer_64b
    end # Target⸬prefer_64b?

    def preferred_arch; @preferred_arch ||= (prefer_64b? ? _64b_arch : _32b_arch); end

    # Utility functions:  Refine their sole parameter in a relevant manner.

    def preferred_arch_as_list; [preferred_arch].extend(ArchitectureListExtension); end

    def select_32b_archs(as); as.select{ |a| _32b_arch?(a) }.extend ArchitectureListExtension; end

    def select_64b_archs(as); as.select{ |a| _64b_arch?(a) }.extend ArchitectureListExtension; end

    # Utility functions:  Return either true or some relevant value, based on their sole parameter.

    def _32b?; bits == 32; end

    def _64b?; bits == 64; end

    def _32b_arch(t = CPU.type)
      case t
        when :intel   then :i386
        when :powerpc then :ppc
      end  # Return nil for any other input.
    end # Target⸬_32b_arch

    def _64b_arch(t = CPU.type)
      case t
        when :arm     then (CPU.arm? and oldest(CPU.model) == :m1) ? :arm64e : :arm64
        when :intel   then (CPU.intel? and oldest(CPU.model) == :haswell) ? :x86_64h : :x86_64
        when :powerpc then :ppc64
      end  # Return nil for any other input.
    end # Target⸬_64b_arch

    def _32b_arch?(a); a == :i386 or a == :ppc; end

    def _64b_arch?(a); not _32b_arch?(a); end

    def bits(obj = model)
      case obj
        when *CPU.known_archs  then CPU.arch_data(obj)[:bits]
        when *CPU.known_models then CPU.model_data(obj)[:bits]
      end  # Return nil for any other input.
    end # Target⸬bits

    def pure_64b?; archset.map(&:to_s).all?{ |a| a =~ %r{64} }; end

    CPU.known_types().each{ |t| define_method("#{t}?") { archset.find{ |a| CPU.type_of(a) == t } } }

    # These return arrays extended via ArchitectureListExtension (see “mach.rb”), which provides helper methods like #as_arch_flags
    # & #as_cmake_arch_flags.  Note that building for 64-bit is only just possible on Tiger & unevenly supported on Leopard.  Don’t
    # even try unless 64‐bit builds are enabled; they generally aren’t, prior to Leopard, although the issue can be forced on Tiger
    # by case‐insensitively setting the environment variable $HOMEBREW_PREFER_64_BIT to “FORCE”.
    # Weirdly, builds for Haswell-architecture :x86_64h and Apple‐silicon :arm64e seem to be absent from the latest Mac OS releases
    # – with unclear implications.
    def all_archs; CPU.known_archs.extend ArchitectureListExtension; end
    def all_our_archs
      o = oldest(CPU.model)
      # Filter out architecture variants our model has a better alternative for (e.g. on Apple silicon, we can run :arm64e; on :arm
      # or Haswell, we can run :x86_64h), or cannot run (e.g. :x86_64h on a pre‐Haswell machine, or :arm64e on :a12z).
      all_archs.reject{ |a| case a
          when :arm64   then o == :m1
          when :arm64e  then o == :a12z
          when :x86_64  then [:haswell, :a12z, :m1].include? o
          when :x86_64h then o == :core2
          else false
        end # case a
      }.extend(ArchitectureListExtension)
    end # Target⸬all_our_archs

    def cross_archs
      (MacOS.version   >= :big_sur)  ? universal_archs_2 \
      : (MacOS.version >= :catalina) ? [_64b_arch(:intel)].extend(ArchitectureListExtension) \
      : (MacOS.version >= :lion)     ? [:i386, _64b_arch(:intel)].extend(ArchitectureListExtension) \
      : (MacOS.version >= :tiger)    ? (prefer_64b? ? ((ENV.respond_to?(:compiler) and ENV.compiler == :clang) ? triple_fat_archs \
                                                                                                               : quad_fat_archs) \
                                                    : universal_archs_1)
      : [:ppc].extend(ArchitectureListExtension)
    end # Target⸬cross_archs

    def local_archs
      @local_archs ||= all_our_archs.select{ |a|
          CPU.can_run?(a) and (MacOS.version < :lion or _64b_arch?(a))
        }.extend(ArchitectureListExtension)
    end

    def quad_fat_archs; [:i386, :ppc, :ppc64, :x86_64].extend(ArchitectureListExtension); end

    def triple_fat_archs; [:i386, :ppc, :x86_64].extend(ArchitectureListExtension); end

    def universal_archs_1; [:i386, :ppc].extend(ArchitectureListExtension); end

    def universal_archs_2; [_64b_arch(:arm), _64b_arch(:intel)].extend(ArchitectureListExtension); end
  end # << self
end # Target
