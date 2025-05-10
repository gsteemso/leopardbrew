class Hardware
  module CPU
    extend self;
    def arch_32_bit;     ::CPU._32b_arch;   end
    def arch_64_bit;     ::CPU._64b_arch;   end
    def intel?;          ::CPU.intel?;      end
    def is_32_bit?;      ::CPU._32b?;       end
    def is_64_bit?;      ::CPU._64b?;       end
    def ppc?;            ::CPU.powerpc?;    end
    def type;            ::CPU.type;        end
    def universal_archs; ::CPU.local_archs; end
  end # Hardware⸬CPU

  class << self
    # We won't change the name because of backward compatibility.
    # So disable rubocop here.
    def is_32_bit? # rubocop:disable Style/PredicateName
      ::CPU._32b?
    end

    # We won't change the name because of backward compatibility.
    # So disable rubocop here.
    def is_64_bit? # rubocop:disable Style/PredicateName
      ::CPU._64b?
    end

    def bits; ::CPU.bits; end

    def cpu_type; ::CPU.type; end

    def cpu_family; ::CPU.model; end
    alias_method :intel_family, :cpu_family
    alias_method :ppc_family, :cpu_family

    def oldest_cpu; ::CPU.oldest; end

    def processor_count; ::CPU.cores; end
  end # << self
end # Hardware
