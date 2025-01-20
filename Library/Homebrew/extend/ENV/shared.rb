require 'formula'
require 'compilers'

# Homebrew extends Ruby's `ENV` to make our code more readable.  Implemented in
# {SharedEnvExtension} and either {Superenv} or {Stdenv}, per the build mode.
# @see Superenv
# @see Stdenv
# @see Ruby's ENV API
module SharedEnvExtension
  include CompilerConstants

  # @private
  CC_FLAG_VARS = %w[CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS]
  # @private
  FC_FLAG_VARS = %w[FCFLAGS FFLAGS]
  # @private
  COMPILER_VARS = %w[CC CXX F77 FC OBJC OBJCXX]
  # @private
  SANITIZED_VARS = %w[
    CDPATH GREP_OPTIONS CLICOLOR_FORCE
    CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH
    CC CXX OBJC OBJCXX CPP MAKE LD LDSHARED
    CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS LDFLAGS CPPFLAGS
    MACOSX_DEPLOYMENT_TARGET SDKROOT DEVELOPER_DIR
    CMAKE_PREFIX_PATH CMAKE_INCLUDE_PATH CMAKE_FRAMEWORK_PATH
    GOBIN GOPATH GOROOT
    LIBRARY_PATH
  ]

  # @private
  def setup_build_environment(formula = nil, archset = nil)
    @formula = formula
    reset
    set_build_archs(archset || build_archs || MacOS.preferred_arch_as_list)
  end # setup_build_environment

  # @private
  def reset; SANITIZED_VARS.each { |k| delete(k) }; end

  def remove_cc_etc
    keys = %w[CC CXX OBJC OBJCXX LD CPP CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS LDFLAGS CPPFLAGS]
    removed = Hash[*keys.flat_map { |key| [key, self[key]] }]
    keys.each { |key| delete(key) }
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
    _keys = Array(keys).select{ |k| self[k].chuzzle }
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
      self[key] = self[key].sub(value, '').gsub(/#{sep}{2,}/, sep)
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

  def build_archs;
    ((hba = self['HOMEBREW_BUILD_ARCHS']) ? hba.split(' ') : []).extend ArchitectureListExtension
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
        fetch_compiler(cc, '--cc')
      elsif (cc = homebrew_cc)
        warn_about_non_apple_gcc($&) if cc =~ GNU_GCC_REGEXP
        compiler = fetch_compiler(cc, '$HOMEBREW_CC')
        compiler = CompilerSelector.select_for(@formula, [compiler] + CompilerSelector.compilers) if @formula
        compiler
      elsif @formula then CompilerSelector.select_for(@formula)
      else MacOS.default_compiler; end
  end # compiler

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

  # TODO:  Fix these so they check the correct _versions_ of clang
  def supports_c11?; cc =~ GNU_C11_REGEXP or cc =~ /clang/; end

  def supports_cxx11?; cc =~ GNU_CXX11_REGEXP or cc =~ /clang/; end

  # Snow Leopard defines an NCURSES value the opposite of most distros.
  # See: https://bugs.python.org/issue6848
  # Currently only used by aalib in core.
  def ncurses_define; append 'CPPFLAGS', '-DNCURSES_OPAQUE=0'; end

  def make_jobs
    self['HOMEBREW_MAKE_JOBS'].nuzzle \
      || (self['MAKEFLAGS'] =~ %r{-\w*j(\d)+})[1].nuzzle \
      || Hardware::CPU.cores
  end

  # Edits $MAKEFLAGS, causing Make to use a single job.  This is useful for
  # makefiles with race conditions.  When passed a block, $MAKEFLAGS is altered
  # only within the block, being restored on its completion.
  def deparallelize
    old = self['MAKEFLAGS']; j_rex = /(-\w*j)\d+/
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
    self['LD'] = ld64.bin/'ld'
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
        You may need to:  brew tap homebrew/versions
      EOS
    end # get GCC formula
    unless gcc_formula.opt_prefix.exist?
      raise <<-EOS.undent
      The requested Leopardbrew GCC was not installed.  You must:
          brew install #{gcc_formula.full_name}
      EOS
    end # no GCC formula
  end # warn_about_non_apple_gcc

  def cross_binary; set_build_archs(Hardware::CPU.cross_archs); end

  def universal_binary; set_build_archs(Hardware::CPU.universal_archs); end

  def set_build_archs(archset)
    Hardware::CPU.all_archs.each { |arch| remove COMPILER_VARS, "-arch #{arch}" }
    archset.extend ArchitectureListExtension unless archset.respond_to?(:fat?)
    self['HOMEBREW_BUILD_ARCHS'] = archset.as_build_archs
    append_if_set COMPILER_VARS, archset.as_arch_flags
  end # set_build_archs

  def m32
    @build_arch_stash ||= build_archs
    set_build_archs Hardware::CPU.select_32b_archs(@build_arch_stash)
  end

  def un_m32
    Hardware::CPU.all_32b_archs.each { |af|
      remove COMPILER_VARS, "-arch #{af}"
      remove HOMEBREW_BUILD_ARCHS, af.to_s
    }
    set_build_archs @build_arch_stash
  end

  def m64
    @build_arch_stash ||= build_archs
    set_build_archs Hardware::CPU.select_64b_archs(@build_arch_stash)
  end

  def un_m64
    Hardware::CPU.all_64b_archs.each do |af|
      remove COMPILER_VARS, "-arch #{af}"
      remove HOMEBREW_BUILD_ARCHS, af.to_s
    end
    set_build_archs @build_arch_stash
  end # un_m64

  private

  def cc=(val); self['CC'] = self['OBJC'] = val.to_s + build_archs.as_arch_flags; end

  def cxx=(val); self['CXX'] = self['OBJCXX'] = val.to_s + build_archs.as_arch_flags; end

  def homebrew_cc; self['HOMEBREW_CC']; end

  def fetch_compiler(value, source)
    COMPILER_SYMBOL_MAP.fetch(value) do |other|
      case other
        when GNU_GCC_REGEXP then other
        else raise "Invalid value for #{source}: #{other}"
      end
    end # fetch do |other|
  end # fetch_compiler
end # SharedEnvExtension
