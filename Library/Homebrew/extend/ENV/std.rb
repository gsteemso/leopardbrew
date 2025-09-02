require 'extend/ENV/shared'

# @deprecated
module Stdenv
  include SharedEnvExtension

  # @private
  SAFE_CFLAGS_FLAGS = "-w -pipe"
  DEFAULT_FLAGS = "-march=core2 -msse4"

  def self.extended(base)
    unless ORIGINAL_PATHS.include? HOMEBREW_PREFIX/"bin"
      base.prepend_path "PATH", "#{HOMEBREW_PREFIX}/bin"
    end
  end

  # @private
  def setup_build_environment(formula = nil, archset = CPU.default_archset)
    super

    if MacOS.version >= '10.8'
      # Mountain Lion's sed errors out on files with mixed character sets
      delete("LC_ALL")
      self["LC_CTYPE"]="C"
    end

    # Set the default pkg-config search path, overriding the built-in paths
    # Anything in PKG_CONFIG_PATH is searched before paths in this variable
    self["PKG_CONFIG_LIBDIR"] = determine_pkg_config_libdir

    # make any aclocal stuff installed in Homebrew available
    self["ACLOCAL_PATH"] = "#{HOMEBREW_PREFIX}/share/aclocal" \
      if MacOS.has_apple_developer_tools? and MacOS::Xcode.provides_autotools?

    # /usr/local is already an -isystem and -L directory so we skip it
    unless HOMEBREW_PREFIX.to_s == "/usr/local"
      self["CPPFLAGS"] = "-isystem#{HOMEBREW_PREFIX}/include"
      self["LDFLAGS"] = "-L#{HOMEBREW_PREFIX}/lib"
      # CMake ignores the variables above
      self["CMAKE_PREFIX_PATH"] = HOMEBREW_PREFIX.to_s
    end

    if (frameworks = HOMEBREW_PREFIX/'Frameworks').directory?
      append ["CPPFLAGS", "LDFLAGS"], "-F#{frameworks}"
      self["CMAKE_FRAMEWORK_PATH"] = frameworks.to_s
    end

    # Os is the default Apple uses for all its stuff so let’s trust them
    set_cflags "-Os #{SAFE_CFLAGS_FLAGS}"

    append "LDFLAGS", "-Wl,-headerpad_max_install_names"

    send(compiler)

    if cc =~ GNU_GCC_REGEXP
      gcc_formula = gcc_version_formula($&)
      append_path "PATH", gcc_formula.opt_bin.to_s
    end

    # Add lib and include etc. from the current macosxsdk to compiler flags:
    macosxsdk MacOS.version

    append_path "PATH", "#{MacOS::Xcode.prefix}/usr/bin:#{MacOS::Xcode.toolchain_path}/usr/bin" \
      if MacOS::Xcode.without_clt?

    # Leopard's ld needs some convincing that it's building 64-bit
    # See: https://github.com/mistydemeo/tigerbrew/issues/59
    if MacOS.version == '10.5' and MacOS.prefer_64_bit? and archset.detect{ |a| a.to_s.ends_with? '64' }
      append 'LDFLAGS', archset.as_arch_flags
      # Many, many builds are broken by Leopard’s buggy ld.  Our ld64 fixes
      # many of them, though obviously we can’t depend on it to build itself.
      ld64 if Formula.factory('ld64').installed?
    end
  end # setup_build_environment

  # @private
  def determine_pkg_config_libdir
    paths = []
    paths << "#{HOMEBREW_PREFIX}/lib/pkgconfig"
    paths << "#{HOMEBREW_PREFIX}/share/pkgconfig"
    paths << "#{HOMEBREW_LIBRARY}/ENV/pkgconfig/#{MacOS.version}"
    paths << "/usr/lib/pkgconfig"
    paths.select { |d| File.directory? d }.join(File::PATH_SEPARATOR)
  end # determine_pkg_config_libdir

  # These methods are no-ops for compatibility.
  %w[fast O4 Og].each { |opt| define_method(opt) {} }

  %w[O3 O2 O1 O0 Os].each do |opt|
    define_method opt do
      remove_from_cflags(/-O./)
      append_to_cflags "-#{opt}"
    end
  end

  # @private
  def determine_cc; s = super; MacOS.locate(s) || Pathname.new(s); end

  # @private
  def determine_cxx
    cc = determine_cc
    cc.dirname/cc.basename.to_s.sub("gcc", "g++").sub("clang", "clang++")
  end

  def gcc_4_0; super; set_cpu_cflags "-march=nocona -mssse3"; end
  alias_method :gcc_4_0_1, :gcc_4_0

  def gcc; super; set_cpu_cflags; end
  alias_method :gcc_4_2, :gcc

  GNU_GCC_VERSIONS.each { |n| define_method(:"gcc-#{n}") do super; set_cpu_cflags; end }

  def llvm; super; set_cpu_cflags; end

  def clang
    super
    replace_in_cflags(/-Xarch_#{CPU._32b_arch} (-march=\S*)/, '\1')
    # Clang mistakenly enables AES-NI on plain Nehalem
    map = CPU.opt_flags_as_map(compiler_version)
    map = map.merge(:nehalem => "-march=native -Xclang -target-feature -Xclang -aes")
    set_cpu_cflags "-march=native", map
  end # clang

  def remove_macosxsdk(version = MacOS.version)
    # Clear all lib and include dirs from CFLAGS, CPPFLAGS, LDFLAGS that were
    # previously added by macosxsdk
    version = version.to_s
    remove_from_cflags(/ ?-mmacosx-version-min=10\.\d/)
    delete("MACOSX_DEPLOYMENT_TARGET")
    delete("CPATH")
    remove "LDFLAGS", "-L#{HOMEBREW_PREFIX}/lib"

    if (sdk = MacOS.sdk_path(version)) and not MacOS::CLT.installed?
      delete("SDKROOT")
      remove_from_cflags "-isysroot #{sdk}"
      remove "CPPFLAGS", "-isysroot #{sdk}"
      remove "LDFLAGS", "-isysroot #{sdk}"
      if HOMEBREW_PREFIX.to_s == "/usr/local"
        delete("CMAKE_PREFIX_PATH")
      else
        # It was set in setup_build_environment, so we have to restore it here.
        self["CMAKE_PREFIX_PATH"] = HOMEBREW_PREFIX.to_s
      end
      remove "CMAKE_FRAMEWORK_PATH", "#{sdk}/System/Library/Frameworks"
    end
  end # remove_macosxsdk

  def macosxsdk(version = MacOS.version)
    # Sets all needed lib and include dirs to CFLAGS, CPPFLAGS, LDFLAGS.
    remove_macosxsdk
    version = version.to_s
    append_to_cflags("-mmacosx-version-min=#{version}")
    self["MACOSX_DEPLOYMENT_TARGET"] = version
    self["CPATH"] = "#{HOMEBREW_PREFIX}/include"
    prepend "LDFLAGS", "-L#{HOMEBREW_PREFIX}/lib"

    if (sdk = MacOS.sdk_path(version)) and not MacOS::CLT.installed?
      # Extra setup to support Xcode 4.3+ without CLT.
      self["SDKROOT"] = sdk
      # Tell clang/gcc where system include's are:
      append_path "CPATH", "#{sdk}/usr/include"
      # The -isysroot is needed, too, because of the Frameworks
      append_to_cflags "-isysroot #{sdk}"
      append "CPPFLAGS", "-isysroot #{sdk}"
      # And the linker needs to find sdk/usr/lib
      append "LDFLAGS", "-isysroot #{sdk}"
      # Needed to build cmake itself and perhaps some cmake projects:
      append_path "CMAKE_PREFIX_PATH", "#{sdk}/usr"
      append_path "CMAKE_FRAMEWORK_PATH", "#{sdk}/System/Library/Frameworks"
    end
  end # macosxsdk

  def minimal_optimization
    set_cflags "-Os #{SAFE_CFLAGS_FLAGS}"
    macosxsdk unless MacOS::CLT.installed?
  end

  def no_optimization
    set_cflags SAFE_CFLAGS_FLAGS
    macosxsdk unless MacOS::CLT.installed?
  end

  # Some configure scripts won't find libxml2 without help
  def libxml2
    append "CPPFLAGS", "-I#{MacOS::CLT.installed? ? MacOS.sdk_path : ''}/usr/include/libxml2"
  end

  def x11
    xinc = MacOS::X11.include.to_s
    xlib = MacOS::X11.lib.to_s
    xshr = MacOS::X11.share.to_s
    append "CFLAGS", "-I#{xinc}" unless MacOS::CLT.installed?
    append "CPPFLAGS", "-I#{xinc} -I#{xinc}/freetype2"
    append "LDFLAGS", "-L#{xlib}"
    append_path "ACLOCAL_PATH", "#{xshr}/aclocal"
    append_path "CMAKE_INCLUDE_PATH", "#{xinc} #{xinc}/freetype2"
    append_path "CMAKE_PREFIX_PATH", MacOS::X11.prefix.to_s
    append_path "CMAKE_PREFIX_PATH", "#{MacOS.sdk_path}/usr/X11" \
                                if MacOS::XQuartz.provided_by_apple? and not MacOS::CLT.installed?
    # There are some config scripts here that should go in the PATH
    append_path "PATH", MacOS::X11.bin.to_s
    # Append these to PKG_CONFIG_LIBDIR so they are searched
    # *after* our own pkgconfig directories, as we dupe some of the
    # libs in XQuartz.
    append_path "PKG_CONFIG_LIBDIR", "#{xlib}/pkgconfig #{xshr}/pkgconfig"
  end # x11
  alias_method :libpng, :x11

  # we've seen some packages fail to build when warnings are disabled!
  def enable_warnings; remove_from_cflags "-w"; end

  def set_build_archs(archset)
    archset = super
    CPU.all_archs.each { |arch| remove_from_cflags "-arch #{arch}" }
    append_to_cflags archset.as_arch_flags
    append "LDFLAGS", archset.as_arch_flags
    self['CMAKE_OSX_ARCHITECTURES'] = archset.as_cmake_arch_flags
    # GCC won’t mix “-march” for a 32-bit CPU with “-arch x86_64”
    replace_in_cflags(/-march=\S*/, '-Xarch_i386 \0') if compiler != :clang and archset.includes? :x86_64
  end # set_build_archs

  # Super filters the build archs to the 32‐bit ones via set_build_archs.
  def m32; super; append_to_cflags "-m32"; end

  # Super filters the build archs to the 64‐bit ones via set_build_archs.
  def m64; super; append_to_cflags "-m64"; end

  # Super restores the filtered‐out build archs via set_build_archs.
  def un_m32; super; remove_from_cflags '-m32'; end
  def un_m64; super; remove_from_cflags '-m64'; end

  def cxx11
    if compiler == :clang
      append "CXX", "-std=c++11 -stdlib=libc++"
    elsif compiler =~ GNU_CXX11_REGEXP then append "CXX", "-std=c++11"
    else raise "The selected compiler doesn't support C++11: #{compiler}"; end
  end # cxx11

  def libcxx; append "CXX", "-stdlib=libc++" if compiler == :clang; end

  def libstdcxx; append "CXX", "-stdlib=libstdc++" if compiler == :clang; end

  # @private
  def replace_in_cflags(before, after)
    CC_FLAG_VARS.each { |key| self[key] = self[key].sub(before, after) if key?(key) }
  end

  # Convenience method to set all C compiler flags in one shot.
  def set_cflags(val); CC_FLAG_VARS.each { |key| self[key] = val }; end

  # Sets architecture-specific flags for every environment variable
  # given in the list `flags`.
  # @private
  def set_cpu_flags(flags, default = DEFAULT_FLAGS, map = CPU.opt_flags_as_map(compiler_version))
    cflags =~ /(-Xarch_#{CPU._32b_arch} )-march=/
    xarch = $1 || ''
    remove flags, /(#{xarch})?-march=\S*/
    remove flags, /( -Xclang \S+)+/
    remove flags, /-mssse3/
    remove flags, /-msse4(\.\d)?/
    append flags, xarch unless xarch.empty?
    append flags, map.fetch(effective_arch, default)
    # Work around a buggy system header on Tiger
    append flags, "-faltivec" if MacOS.version == '10.4' and CPU.powerpc? and not CPU.model == :g3
    # not really a 'CPU' cflag, but is only used with clang
    remove flags, '-Qunused-arguments'
  end # set_cpu_flags

  # @private
  def effective_arch
    if ARGV.build_bottle? then CPU.bottle_target_arch
    elsif CPU.intel? and not CPU.sse4?
      # If the CPU doesn't support SSE4, we cannot trust -march=native or
      # -march=<cpu family> to do the right thing because we might be running
      # in a VM or on a Hackintosh.
      CPU.oldest(CPU._64b? ? :x86_64 : :i386)
    else CPU.model
    end
  end # effective_arch

  # @private
  def set_cpu_cflags(default = DEFAULT_FLAGS, map = CPU.opt_flags_as_map(compiler_version))
    set_cpu_flags CC_FLAG_VARS, default, map
  end

  # This method does nothing in stdenv since there's no arg refurbishment
  # @private
  def refurbish_args; end
end
