require 'compilers'
require 'formula'
require 'target'  # pulls in macos for us, which pulls in cpu

# Homebrew extends Ruby's `ENV` to make our code more readable.  Implemented in
# {SharedEnvExtension} and either {Superenv} or {Stdenv}, per the build mode.
# @see Superenv
# @see Stdenv
# @see Ruby's ENV API
module SharedEnvExtension
  include CompilerConstants

  attr_reader :build_archs, :formula_name

  # @private
  CC_FLAG_VARS = %w[CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS]
  # @private
  FC_FLAG_VARS = %w[FCFLAGS FFLAGS]
  # @private
  COMPILER_VARS = %w[CC CXX FC OBJC OBJCXX]
  # @private
  SANITIZED_VARS = %w[
    CDPATH GREP_OPTIONS
    CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH
    CC CXX OBJC OBJCXX CPP MAKE LD LDSHARED
    CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS LDFLAGS CPPFLAGS
    MACOSX_DEPLOYMENT_TARGET SDKROOT DEVELOPER_DIR
    CMAKE_PREFIX_PATH CMAKE_INCLUDE_PATH CMAKE_FRAMEWORK_PATH
    GOBIN GOPATH GOROOT
    LIBRARY_PATH
  ] # CLICOLOR_FORCE  ← why was this in there?

  # @private
  def setup_build_environment(formula, archset)
    @formula = formula
    @formula_name = formula.full_name if formula
    reset
    @build_archs = archset || homebrew_build_archs || MacOS.preferred_arch_as_list
    set_build_archs(build_archs)
    self['MAKEFLAGS'] ||= "-j#{make_jobs}"
  end # setup_build_environment

  # @private
  def reset; SANITIZED_VARS.each { |k| delete(k) }; end

  def remove_cc_etc
    keys = COMPILER_VARS + CC_FLAG_VARS + FC_FLAG_VARS + %w[LD CPP LDFLAGS CPPFLAGS]
    removed = Hash[*keys.flat_map{ |key| [key, self[key]] }]
    keys.each{ |key| delete(key) }
    removed
  end # remove_cc_etc

  def append_to_cflags(newflags); append(CC_FLAG_VARS, newflags); end

  def remove_from_cflags(val); remove CC_FLAG_VARS, val; end

  def append(keys, value, separator = ' ')
    value = value.to_s
    Array(keys).each do |key|
      old = self[key]
      if old.nil? or old.empty? then self[key] = value
      else self[key] += separator + value; end
    end
  end # append

  def prepend(keys, value, separator = ' ')
    value = value.to_s
    Array(keys).each do |key|
      old = self[key]
      if old.nil? or old.empty? then self[key] = value
      else self[key] = value + separator + old; end
    end
  end # prepend

  def append_if_set(keys, value, separator = ' ')
    _keys = Array(keys).select{ |k| self[k].choke }
    append(_keys, value, separator)
  end

  def not_already_in?(key, query)
    old = self[key]
    old.nil? or old.empty? or old.index(query.to_s).nil?
  end

  def append_path(key, dirname)
    append key, dirname, File::PATH_SEPARATOR \
      if File.directory?(dirname) and not_already_in?(key, dirname)
  end

  # Prepends a directory to `PATH`.
  # Is the formula struggling to find the pkgconfig file? Point it to it.
  # This is done automatically for `keg_only` formulae.
  # <pre>ENV.prepend_path 'PKG_CONFIG_PATH', "#{Formula['glib'].opt_lib}/pkgconfig"</pre>
  def prepend_path(key, dirname)
    prepend key, dirname, File::PATH_SEPARATOR \
      if File.directory?(dirname) and not_already_in?(key, dirname)
  end

  def prepend_create_path(key, path)
    path = Pathname.new(path) unless path.is_a? Pathname
    path.mkpath
    prepend_path key, path
  end

  def remove(keys, value, sep = ' ')
    Array(keys).each do |key|
      next unless self[key]
      # Make sure to only delete whole entries – not from the middle of one.
      self[key] = self[key].sub(/(\W)#{value}(?!\w)/, $1 || '').gsub(/#{sep}{2,}/, sep).chomp
      delete(key) if self[key].empty?
    end if value
  end # remove

  def cc; self['CC']; end

  def cxx; self['CXX']; end

  def cflags; self['CFLAGS']; end

  def cxxflags; self['CXXFLAGS']; end

  def cppflags; self['CPPFLAGS']; end

  def ldflags; self['LDFLAGS']; end

  def fc; self['FC']; end

  def fflags; self['FFLAGS']; end

  def fcflags; self['FCFLAGS']; end

  def homebrew_build_archs
    if (hba = self['HOMEBREW_BUILD_ARCHS'].choke)
      hba.split(' ').extend ArchitectureListExtension
    end
  end

  # Outputs the current compiler.
  # @return [Symbol]
  # <pre># Do something only for clang
  # if ENV.compiler == :clang
  #   # modify CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS in one go:
  #   ENV.append_to_cflags '-I ./missing/includes'
  # end</pre>
  def compiler
    @compiler ||= \
      if (cc = ARGV.cc)
        warn_about_non_apple_gcc($&) if cc =~ GNU_GCC_REGEXP
        CompilerSelector.validate_user_compiler(@formula, fetch_compiler(cc, '--cc'))
      elsif (cc = homebrew_cc)
        warn_about_non_apple_gcc($&) if cc =~ GNU_GCC_REGEXP
        compiler = fetch_compiler(cc, '$HOMEBREW_CC')
        compiler = CompilerSelector.select_for(@formula, [compiler] + CompilerSelector.compilers) if @formula
        compiler
      elsif @formula then CompilerSelector.select_for(@formula)
      else MacOS.default_compiler; end
  end # compiler

  def compiler_version; CompilerSelector.compiler_version(compiler); end

  # @private
  def determine_cc; COMPILER_SYMBOL_MAP.invert.fetch(compiler, compiler); end

  # @private
  def determine_cxx; determine_cc.to_s.gsub('gcc', 'g++').gsub('clang', 'clang++'); end

  COMPILERS.each do |compiler|
    define_method(compiler) do
      @compiler = compiler
      # The assignment accessors take care of adding the archflags.
      self.cc  = determine_cc
      self.cxx = determine_cxx
    end
  end # define a method for each |compiler| in COMPILERS, for use exactly once during setup

  def default_c_version(comp = compiler)
    case comp
      when GNU_C11_DEFAULT_REGEXP then :c11
#     when :clang then ???
      else :c89
    end
  end # default_c_version

  def default_cxx_version(comp = compiler)
    case comp
      when GNU_CXX14_DEFAULT_REGEXP then :cxx14
#     when :clang then ???
      else :cxx98
    end
  end # default_cxx_version

# TODO:  Fix this to check the correct _version_ of clang
  def supports_c11?; cc =~ GNU_C11_REGEXP or cc =~ /clang/; end

  def supports_cxx11?
    cc =~ GNU_CXX11_REGEXP or (cc =~ /clang/ and MacOS.clang_version.to_f >= CLANG_CXX11_MIN.to_f)
  end

# TODO:  Fix this to check the correct _version_ of clang
  def supports_cxx14?; cc =~ GNU_CXX14_REGEXP or cc =~ /clang/; end

  def building_pure_64_bit?; build_archs.all?{ |a| a.to_s =~ /64/ }; end

  # Snow Leopard defines an NCURSES value the opposite of most distros.
  # See: https://bugs.python.org/issue6848
  # Currently only used by aalib in core.
  def ncurses_define; append 'CPPFLAGS', '-DNCURSES_OPAQUE=0'; end

  def make_jobs
    self['HOMEBREW_MAKE_JOBS'].nope \
      || (self['MAKEFLAGS'] =~ %r{-\w*j(\d+)})[1].nope \
      || 2 * CPU.cores
  end

  # Edits $MAKEFLAGS, restricting Make to a single job.  This is useful for makefiles with race
  # conditions.  When passed a block, $MAKEFLAGS is altered only within the block, being restored
  # on its completion.
  def deparallelize
    old = self['MAKEFLAGS']; j_rex = %r{(-\w*j)\d+}
    if old =~ j_rex then self['MAKEFLAGS'] = old.sub(j_rex, '\11')
    else append 'MAKEFLAGS', '-j1'; end
    begin; yield; ensure; self['MAKEFLAGS'] = old; end if block_given?
    old
  end
  alias_method :j1, :deparallelize

  # @private
  def userpaths!
    paths = self['PATH'].split(File::PATH_SEPARATOR)
    # put Superenv.bin and opt paths first
    new_paths = paths.select { |p|
        p.starts_with?("#{HOMEBREW_LIBRARY}/ENV") || p.starts_with?(OPTDIR.to_s)
      }
    # XXX hot fix to prefer brewed stuff (e.g. python) over /usr/bin.
    new_paths << "#{HOMEBREW_PREFIX}/bin"
    # reset of self['PATH']
    new_paths += paths
    # user paths
    new_paths += ORIGINAL_PATHS.map { |p| p.realpath.to_s rescue nil } - %w[/usr/X11/bin /opt/X11/bin]
    self['PATH'] = new_paths.uniq.join(File::PATH_SEPARATOR)
  end # userpaths!

  def fortran
    flags = []
    if fc
      ohai 'Building with an assigned Fortran compiler', 'This is unsupported.'
      self['F77'] ||= fc
      if ARGV.include? '--default-fortran-flags'
        flags = FC_FLAG_VARS.reject { |key| self[key] }
      elsif values_at(*FC_FLAG_VARS).compact.empty?
        opoo <<-EOS.undent
          No Fortran optimization information was provided.  You may want to consider
          setting FCFLAGS and FFLAGS or pass the `--default-fortran-flags` option to
          `brew install` if your compiler is compatible with GCC.

          If you like the default optimization level of your compiler, ignore this
          warning.
        EOS
      end # FC flag vars are all empty
    else # no fc
      if (gfortran = which('gfortran', "#{HOMEBREW_PREFIX}/bin"))
        ohai 'Using Leopardbrew‐provided fortran compiler.'
      elsif (gfortran = which('gfortran', ORIGINAL_PATHS.join(File::PATH_SEPARATOR)))
        ohai "Using a fortran compiler found at #{gfortran}."
      end
      if gfortran
        puts 'This may be changed by setting the FC environment variable.'
        self['FC'] = self['F77'] = gfortran
        flags = FC_FLAG_VARS
      end
    end # no fc
    flags.each { |key| self[key] = cflags }
    set_cpu_flags(flags)
  end # fortran

  # ld64 is a newer linker provided for Xcode 2.5 (and 3.1)
  # @private
  def ld64
    ld64 = Formulary.factory('ld64')
    self['LD'] = "#{ld64.bin}/ld"
    append 'LDFLAGS', "-B#{ld64.bin}/"
  end

  # @private
  def gcc_version_formula(name)
    version = name[GNU_GCC_REGEXP, 1]
    gcc_version_name = "gcc#{version.delete('.')}"
    gcc = Formulary.factory('gcc')
    if gcc.version_suffix == version then gcc
    else Formulary.factory(gcc_version_name); end
  end # gcc_version_formula

  # @private
  def warn_about_non_apple_gcc(name)
    begin
      gcc_formula = gcc_version_formula(name)
    rescue FormulaUnavailableError => e
      raise <<-EOS.undent
        Leopardbrew GCC requested, but formula #{e.name} not found!
        You may need to:
            brew tap homebrew/versions
      EOS
    end # get GCC formula
    unless gcc_formula.opt_prefix.exists?
      raise <<-EOS.undent
      The requested Leopardbrew GCC is not installed.  You must:
          brew install #{gcc_formula.full_name}
      EOS
    end # no opt/ prefix
  end # warn_about_non_apple_gcc

  def cross_binary; set_build_archs(CPU.cross_archs); end

  def universal_binary; set_build_archs(CPU.local_archs); end

  def set_build_archs(archset)
    archset = Array(archset).extend ArchitectureListExtension unless archset.responds_to?(:fat?)
    clear_compiler_archflags
    if @without_archflags then @without_archflags = false; end
    @build_archs = archset
    self['HOMEBREW_BUILD_ARCHS'] = archset.as_build_archs
    self['CMAKE_OSX_ARCHITECTURES'] = archset.as_cmake_arch_flags
    set_compiler_archflags archset.as_arch_flags
    archset
  end # set_build_archs

  def without_archflags
    @without_archflags = true
    clear_compiler_archflags
    arch_flags = delete 'HOMEBREW_ARCHFLAGS' if superenv?
    cmake_archs = delete 'CMAKE_OSX_ARCHITECTURES'
    begin
      yield
    ensure
      @without_archflags = false
      set_compiler_archflags
      self['HOMEBREW_ARCHFLAGS'] = arch_flags if superenv?
      self['CMAKE_OSX_ARCHITECTURES'] = cmake_archs
    end if block_given?
  end # without_archflags

  def clear_compiler_archflags
    CPU.all_archs.each{ |arch| remove COMPILER_VARS, "-arch #{arch}" }
  end

  def set_compiler_archflags(flagstring = build_archs.as_arch_flags)
    append_if_set COMPILER_VARS, flagstring
  end

  def m32
    if @without_archflags
      set_compiler_archflags '-m32'
    else
      @build_arch_stash ||= build_archs
      set_build_archs CPU.select_32b_archs(@build_arch_stash)
    end
  end # m32

  def m64
    if @without_archflags
      set_compiler_archflags '-m64'
    else
      @build_arch_stash ||= build_archs
      set_build_archs CPU.select_64b_archs(@build_arch_stash)
    end
  end # m64

  def un_m32
    if @without_archflags
      remove COMPILER_VARS, '-m32'
    else
      set_build_archs @build_arch_stash
      @build_arch_stash = nil
    end
  end

  def un_m64
    if @without_archflags
      remove COMPILER_VARS, '-m64'
    else
      set_build_archs @build_arch_stash
      @build_arch_stash = nil
    end
  end

  private

  def cc=(val)
    self['HOMEBREW_CC'] = val.to_s
    if val then self['CC'] = self['OBJC'] = homebrew_cc + ' ' + build_archs.as_arch_flags
    else        self['CC'] = self['OBJC'] = ''; end
  end

  def cxx=(val)
    self['HOMEBREW_CXX'] = val.to_s
    if val then self['CXX'] = self['OBJCXX'] = homebrew_cxx + ' ' + build_archs.as_arch_flags
    else        self['CXX'] = self['OBJCXX'] = ''; end
  end

  def homebrew_cc; self['HOMEBREW_CC']; end

  def homebrew_cxx; self['HOMEBREW_CXX']; end

  def fetch_compiler(name, source)
    COMPILER_SYMBOL_MAP.fetch(name) do |other|
      case other
        when GNU_GCC_REGEXP then other
        else raise "Invalid value for #{source}:  #{other}"
      end
    end # fetch do |other|
  end # fetch_compiler
end # SharedEnvExtension
