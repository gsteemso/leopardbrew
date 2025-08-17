# The four C revisions are [:c89, :c99, :c11, :c23].
# (GCC support for :c99 was so lacklustre that the default implementation went from :c89 in GCC 4.9
#  to :c11 in GCC 5.)
# The six C++ revisions are [:cxx98, :cxx11, :cxx14, :cxx17, :cxx20, :cxx23].
# (GCC support for C++11 was delayed long enough that the default implementation went from :cxx98
#  in GCC 5 to :cxx14 in GCC 6.)
# Other nominal revisions of each language exist, but are effectively redundant.

# @private
module CompilerConstants
  GNU_GCC_VERSIONS = %w[4.3 4.4 4.5 4.6 4.7 4.8 4.9 5 6 7 8]
  GNU_GCC_REGEXP = /^gcc-(4\.[3-9]|[5-8])$/

  GNU_C11_REGEXP = /^gcc-(4\.9|[5-8])$/
  # C23 is not yet stable as of GCC 15.
  GNU_CXX11_REGEXP = /^gcc-(4\.[89]|[5-8])$/
  GNU_CXX14_REGEXP = /^gcc-([5-8])$/
  # C++17 is stable from GCC 9.  C++20 is mostly stable as of GCC 13 and C++23 as of GCC 15.
# CLANG_C99_MIN = ???
# CLANG_C11_MIN = ???
# CLANG_C23_MIN = ???
  CLANG_CXX11_MIN = '5.0'
# CLANG_CXX14_MIN = ???
# CLANG_CXX17_MIN = ???
# CLANG_CXX20_MIN = ???
# CLANG_CXX23_MIN = ???

  GNU_C11_DEFAULT_REGEXP   = /^gcc-([5-8])$/  # Older versions defaulted to C89.
  GNU_CXX14_DEFAULT_REGEXP = /^gcc-([6-8])$/  # Older versions defaulted to C++98.
  # C++17 is the default from GCC 11 through 15.
# CLANG_C99_DEFAULT_MIN = ???
# CLANG_C11_DEFAULT_MIN = ???
# CLANG_C23_DEFAULT_MIN = ???
# CLANG_CXX11_DEFAULT_MIN = ???
# CLANG_CXX14_DEFAULT_MIN = ???
# CLANG_CXX17_DEFAULT_MIN = ???
# CLANG_CXX20_DEFAULT_MIN = ???
# CLANG_CXX23_DEFAULT_MIN = ???

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
            raise AlienCompilerError.new(name)
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
             :gcc => ['4.3', '4.4', '4.5', '4.6', '4.7']),
      # the very last features of C++11 were not stable until GCC 4.8.1
      create(:gcc => '4.8') { version = '4.8.0' }
    ],
    :cxx14 => [
      create([:gcc_4_0, :gcc, :llvm]),
      create(:clang),  # build unknown
      create(:gcc => ['4.3', '4.4', '4.5', '4.6', '4.7', '4.8', '4.9'])
      # the very last features of C++14 were not stable until GCC 5.2:
      create(:gcc => '5') { version = '5.1' }
    ],
    :openmp => [
      create(:clang),  # build unknown
      create(:llvm)
    ],
    :tls => [
      create([:gcc_4_0, :gcc, :llvm]),
      create(:clang => 421)  # exact build unknown
      # not sure when GCC gained its workaround... version 4.3? 4.4? at latest 4.9, as required by C11
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

  class << self
    def select_for(formula, compilers = self.compilers); new(formula, compilers).compiler; end

    def compilers; COMPILER_PRIORITY.fetch(MacOS.default_compiler); end

    def compiler_version(name)
      name =~ CompilerConstants::GNU_GCC_REGEXP ? MacOS.non_apple_gcc_version(name) \
                                                : MacOS.send("#{name}_build_version")
    end

    def validate_user_compiler(formula, sym); new(formula, [sym]).validate_user_compiler(sym); end
  end # << self

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

  def validate_user_compiler(sym)
    if (find_compiler { |c| fails_with?(c) })
      name = COMPILER_SYMBOL_MAP.invert.fetch(sym) do
          if sym.to_s =~ CompilerConstants::GNU_GCC_REGEXP then sym
          else raise AlienCompilerError.new(sym); end
        end
      raise ChosenCompilerError.new(formula, name)
    else sym; end
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
