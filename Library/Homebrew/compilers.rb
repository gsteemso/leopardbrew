# @private
module CompilerConstants
  GNU_GCC_VERSIONS = %w[4.3 4.4 4.5 4.6 4.7 4.8 4.9 5 6 7 8]
  GNU_GCC_REGEXP = /^gcc-(4\.[3-9]|[5-8])$/
  GNU_CXX11_REGEXP = /^gcc-(4\.[89]|[5-8])$/
  GNU_CXX14_REGEXP = /^gcc-([5-8])$/
  GNU_C11_REGEXP = /^gcc-(4\.9|[5-8])$/
  CLANG_CXX11_MIN = '5'
  COMPILER_SYMBOL_MAP = {
    "gcc-4.0"  => :gcc_4_0,
    "gcc-4.2"  => :gcc,
    "llvm-gcc" => :llvm,
    "clang"    => :clang
  }

  COMPILERS = COMPILER_SYMBOL_MAP.values +
              GNU_GCC_VERSIONS.map { |n| "gcc-#{n}" }
end # CompilerConstants

class CompilerFailure
  attr_reader :name
  attr_rw :version

  # Allows Apple compiler `fails_with` statements to keep using `build`
  # even though `build` and `version` are the same internally
  alias_method :build, :version

  # The cause is no longer used so we need not hold a reference to the string
  def cause(_); end

  def self.for_standard(std)
    COLLECTIONS.fetch(std) { raise ArgumentError, "“#{std}” is not a recognized standard." }
  end

  def self.create(spec, &block)
    # Non-Apple compilers are in the format fails_with compiler => version
    if spec.is_a?(Hash)
      spec.each do |name, build_or_major_version|
        case name
          when :gcc
            if Array === build_or_major_version
              build_or_major_version.each{ |bv| create(name => bv) }
            else
              name = "gcc-#{build_or_major_version}"
              # so fails_with :gcc => '4.8' simply marks all 4.8 releases incompatible
              version = "#{build_or_major_version}.999"
            end
          when :clang, :gcc_4_0, :llvm
            version = build_or_major_version
          else
            raise ArgumentError, "Compiler “#{name}”?  Sorry, Leopardbrew only knows about GCC variants and Clang."
        end # case |name|
      end # each spec |name & build/version|
    elsif spec.is_a?(Array)
      raise ArgumentError, 'Can’t use a block when listing multiple compiler versions.' if block_given?
      spec.each{ |s| create(s) }
    else
      name = spec
      version = 9999
    end
    new(name, version, &block)
  end # CompilerFailure⸬create

  def initialize(name, version, &block)
    @name = name
    @version = version
    instance_eval(&block) if block_given?
  end

  def ===(compiler); name == compiler.name && version >= compiler.version; end

  def inspect; "#<#{self.class.name}: #{name} #{version}>"; end

  COLLECTIONS = {
    :c11 => [
      create([:gcc_4_0, :gcc, :llvm]),
      create(:clang),  # build unknown
      create(:gcc => ['4.3', '4.4', '4.5', '4.6', '4.7', '4.8'])
    ],
    :cxx11 => [
      create([:gcc_4_0, :gcc, :llvm]),
      create(:clang => 425,
             :gcc => ['4.3', '4.4', '4.5', '4.6', '4.7'])
      # the very last features of C++11 were not stable until GCC 4.8.1
      create(:gcc => '4.8') do version = '4.8.0'; end
    ],
    :cxx14 => [
      create([:gcc_4_0, :gcc, :llvm]),
      create(:clang),  # build unknown
      # the very last features of C++14 were not stable until GCC 5.x:
      create(:gcc => ['4.3', '4.4', '4.5', '4.6', '4.7', '4.8', '4.9'])
    ],
    :openmp => [
      create(:clang),  # build unknown
      create(:llvm)
    ],
    :tls => [
      create([:gcc_4_0, :gcc, :llvm]),
      create(:clang)  # build unknown
      # not sure when GCC gained its workaround... version 4.3? 4.4?
    ]
  }
end # CompilerFailure

class CompilerSelector
  include CompilerConstants

  Compiler = Struct.new(:name, :version)

  COMPILER_PRIORITY = {
    :clang   => [:clang, :gcc, :llvm, :gnu, :gcc_4_0],
    :gcc     => [:gcc, :llvm, :gnu, :clang, :gcc_4_0],
    :llvm    => [:llvm, :gcc, :gnu, :clang, :gcc_4_0],
    :gcc_4_0 => [:gcc_4_0, :gcc, :llvm, :gnu, :clang]
  }

  def self.select_for(formula, compilers = self.compilers)
    new(formula, compilers).compiler
  end

  def self.compilers; COMPILER_PRIORITY.fetch(MacOS.default_compiler); end

  def self.compiler_version(name)
    if name =~ GNU_GCC_REGEXP
      MacOS.non_apple_gcc_version(name)
    else
      MacOS.send("#{name}_build_version")
    end
  end # compiler_version

  attr_reader :formula, :failures, :compilers

  def initialize(formula, compilers)
    @formula = formula
    @failures = formula.compiler_failures
    @compilers = compilers
  end

  def compiler
    find_compiler { |c| return c.name unless fails_with?(c) }
    raise CompilerSelectionError.new(formula)
  end

  private

  def find_compiler
    compilers.each do |compiler|
      if compiler == :gnu
        GNU_GCC_VERSIONS.reverse.each do |v|
          name = "gcc-#{v}"
          version = self.class.compiler_version(name)
          yield Compiler.new(name, version) if version
        end
      else
        version = self.class.compiler_version(compiler)
        yield Compiler.new(compiler, version) if version
      end
    end
  end # find_compiler

  def fails_with?(compiler); failures.any? { |failure| failure === compiler }; end
end # CompilerSelector
