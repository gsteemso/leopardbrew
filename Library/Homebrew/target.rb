require 'macos'  # pulls in cpu for us

class Target
  class << self
    # What CPU model are we building for?  Either explicitly passed via --bottle-arch=, or native.
    def model
      @model ||= ((ARGV.build_bottle? and ba = ARGV.bottle_arch) ? CPU.bottle_model_for(ba) \
                   # On an x86 CPU without SSE4, neither -march=native nor -march=#{model} can be
                   #   trusted, because we might be running in a VM or on a Hackintosh.
                   : ((CPU.intel? and not CPU.sse4?) ? CPU.bottle_model_for(CPU.arch) \
                   : CPU.model))
    end # Target⸬model

    def arch
      @arch ||= ((ARGV.build_bottle? and ba = ARGV.bottle_arch) ? CPU.arch(ba) : MacOS.preferred_arch)
    end

    def type
      @type ||= ((ARGV.build_bottle? and ba = ARGV.bottle_arch) ? CPU.hw_type_of(ba) : CPU.type)
    end

    def bits
      CPU.bit_width(arch)
    end

    CPU.known_types.each { |t| define_method("#{t}?") { type == t } }

    def universal
      archmap = {}
      CPU.type_archs(type).each{ |a| archmap[a] = CPU.archmap(a) }
      archmap
    end
  end # << self
end # Target
