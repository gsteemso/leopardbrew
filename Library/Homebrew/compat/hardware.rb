class Hardware
  class << self
    CPU = ::CPU

    # We won't change the name because of backward compatibility.
    # So disable rubocop here.
    def is_32_bit? # rubocop:disable Style/PredicateName
      CPU._32b?
    end

    # We won't change the name because of backward compatibility.
    # So disable rubocop here.
    def is_64_bit? # rubocop:disable Style/PredicateName
      CPU._64b?
    end

    def bits; CPU.bits; end

    def cpu_type; CPU.type; end

    def cpu_family; CPU.model; end
    alias_method :intel_family, :cpu_family
    alias_method :ppc_family, :cpu_family

    def processor_count; CPU.cores; end
  end # << self
end # Hardware
