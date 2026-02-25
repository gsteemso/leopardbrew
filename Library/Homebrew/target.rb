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

    def filter_archs(archset); @permissible_archs ? archset.select{ |a| @permissible_archs.include?(a) }.extend(ALE) : archset; end

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
      @arch ||= ((b_arch = ARGV.bottle_arch) ? CPU.arch_of(oldest b_arch) : preferred_arch)
      if @permissible_archs and not @permissible_archs.include?(@arch) then die_from_filter([@arch]); end
      @arch
    end

    # What set of architectures are we building for?  A declared bottle architecture, or a preferred native architecture, or else a
    # universal build that includes every native, or every runnable, or every buildable, architecture.
    def archset
      desired_archset = @@formula_can_be_universal ? tool_host_archset : plain_arch
      result = filter_archs desired_archset
      die_from_filter(desired_archset) if result.empty?
      result
    end # Target⸬archset

    # What set of architectures should tools we build be able to run on?  All of our regular universal targets (assuming, of course,
    # that we’re running a universal build in the first place).  If we’re building a bottle, we won’t be building fat; the bottle’s
    # architecture will be the only one in here, via Target⸬arch.
    def tool_host_archset; send("#{ARGV.build_mode}_archs".to_sym); end

    # This architecture set is for the end targets of tools we build (e.g. compilers).  It ought to encompass absolutely everything
    # we have the information to build for.
    def tool_target_archset
      (MacOS.sdk_path/'usr/include/architecture').subdirs.map{ |d| d.basename.to_s.to_sym }.select{ |a|
        all_archs.include? a }.map{ |a| CPU.type_of a }.flat_map{ |t| CPU.archs_of_type t }.extend ALE
      # Ideally, in the presence of the iPhoneOS SDK, we would also incorporate the list of available arm32 subarchitectures.  Alas,
      # computing that set is non‐trivial, & derives several constants in passing which are also required by certain of the formulæ
      # which would use the list.  The additional computation is better done locally therein.
    end # Target⸬tool_target_archset

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
      if CPU.model_data(m)
        if ENV.compiler != :clang # assume is some variant of GCC
          if (vers = CPU.which_gcc_knows_about(m))
            (ENV.compiler_version >= vers ? CPU.model_data(m)[:gcc][:flags] : CPU.gcc_flags_for_post_(vers, CPU.type_of(m)))
          end
        end
      else
        case CPU.type_of(m)
#         when :arm     then ???
          when :intel   then (bits(m) == 64 ? '-march=nocona'   : '-march=i386')
          when :powerpc then (bits(m) == 64 ? '-mcpu=powerpc64' : '-mcpu=powerpc')
          else ''
        end
      end
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
                                         (MacOS.version == :leopard and envflag = ENV['HOMEBREW_PREFER_64_BIT'].choke) or
                                         (MacOS.version == :tiger and envflag and envflag.downcase == 'force')
                        )              )
      end
      @prefer_64b
    end # Target⸬prefer_64b?

    def preferred_arch; @preferred_arch ||= (prefer_64b? ? _64b_arch : _32b_arch); end

    # Utility functions:  Refine their sole parameter in a relevant manner.

    def preferred_arch_as_list; [preferred_arch].extend(ALE); end

    def select_32b_archs(as); as.select{ |a| _32b_arch?(a) }.extend(ALE); end

    def select_64b_archs(as); as.reject{ |a| _32b_arch?(a) }.extend(ALE); end

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
        when :arm     then :arm64
        when :intel   then :x86_64
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

    def pure_64b?; archset.map(&:to_s).all?{ |a| a.ends_with? '64' }; end

    CPU.known_types().each{ |t| define_method("#{t}?") { archset.find{ |a| CPU.type_of(a) == t } } }

    def default_universal_mode
      n8ive_archs.length > 1 ? :n8ive : \
      local_archs.length > 1 ? :local : \
      cross_archs.length > 1 ? :cross : :plain
    end

    def will_run(this)
      v = MacOS.version
      CPU.can_run?(this) and _32b_arch?(this) ? (v < :lion) : (v > :tiger or (v == :tiger and prefer_64b?))
    end

    # These return arrays extended via ALE (ArchitectureListExtension; see “mach.rb”), which provides such useful helper methods as
    # #as_arch_flags & #as_cmake_arch_flags.  Note that building for 64-bit is only just possible on Tiger, & unevenly supported on
    # Leopard.  Don’t even try unless 64‐bit builds are enabled; they generally aren’t, prior to Leopard, although the issue can be
    # forced on Tiger by case‐insensitively setting the environment variable $HOMEBREW_PREFER_64_BIT to “FORCE”.
    def all_archs; CPU.known_archs.extend ALE; end

    def cross_archs
      v = MacOS.version
      (v >= :big_sur)                  ? universal_archs_2     : \
      (v >= :catalina)                 ? [:x86_64].extend(ALE) : \
      (v >= :lion)                     ? CPU.archs(:intel)     : \
      (v <  :tiger)                    ? [:ppc].extend(ALE)    : \
      (not prefer_64b?)                ? universal_archs_1     : \
      (ENV.responds_to?(:compiler) and
        ENV.compiler != :clang)        ? quad_fat_archs        : triple_fat_archs
    end # Target⸬cross_archs

    def local_archs; @local_archs ||= all_archs.select{ |a| will_run(a) }.extend(ALE); end

    def native_archs; CPU.archs.select{ |a| will_run(a) }.extend(ALE); end
    alias_method :n8ive_archs, :native_archs

    def plain_arch; [arch].extend(ALE); end
    alias_method :plain_archs, :plain_arch
    alias_method :bottL_archs, :plain_arch

    def quad_fat_archs; [:i386, :ppc, :ppc64, :x86_64].extend(ALE); end

    def triple_fat_archs; [:i386, :ppc, :x86_64].extend(ALE); end

    def universal_archs_1; [:i386, :ppc].extend(ALE); end

    def universal_archs_2; [:arm64, :x86_64].extend(ALE); end
  end # << self
end # Target
