# This file is loaded before `global.rb`, so must eschew most Homebrew‐isms at
# eval time.

require "hardware"
require "os/mac/version"
require "os/mac/xcode"
require "os/mac/xquartz"

module OS
  module Mac
    extend self

    ::MacOS = self # compatibility

    def prefer_64_bit?
      Hardware::CPU.is_64_bit? and version > :leopard or
                                 (version == :leopard and ENV["HOMEBREW_PREFER_64_BIT"])
    end

    def locate(tool)
      # Don't call tools (cc, make, strip, etc.) directly!
      # Give the name of the binary you look for as a string to this method
      # in order to get the full path back as a Pathname.
      (@locate ||= {}).fetch(tool) do |key|
        @locate[key] = if File.executable?(path = "/usr/bin/#{tool}")
          Pathname.new path
        # Homebrew GCCs most frequently; much faster to check this before xcrun
        elsif (path = HOMEBREW_PREFIX/"bin/#{tool}").executable?
          path
        # xcrun was introduced in Xcode 3 on Leopard
        elsif MacOS.version > :tiger
          path = Utils.popen_read("/usr/bin/xcrun", "-no-cache", "-find", tool).chomp
          Pathname.new(path) if File.executable?(path)
        end
      end
    end # locate(tool)

    # Locates a (working) copy of install_name_tool, guaranteed to function
    # whether the user has developer tools installed or not.
    def install_name_tool
      if (path = OPTDIR/'cctools/bin/install_name_tool').executable?
        path
      else
        locate("install_name_tool")
      end
    end # install_name_tool

    # Locates a (working) copy of lipo, guaranteed to function whether the user
    # has developer tools installed or not.
    def lipo
      if (path = OPTDIR/'cctools/bin/lipo').executable?
        path
      else
        locate("lipo")
      end
    end # lipo

    # Locates a (working) copy of otool, guaranteed to function whether the user
    # has developer tools installed or not.
    def otool
      if (path = OPTDIR/'cctools/bin/otool').executable?
        path
      else
        locate("otool")
      end
    end # otool

    # Checks if the user has any developer tools installed, either via Xcode
    # or the CLT. Convenient for guarding against formula builds when building
    # is impossible.
    def has_apple_developer_tools?; Xcode.installed? or CLT.installed?; end

    def active_developer_dir
      # xcode-select was introduced in Xcode 3 on Leopard
      return "/Developer" if MacOS.version < :leopard

      @active_developer_dir ||= Utils.popen_read("/usr/bin/xcode-select", "-print-path").strip
    end # active_developer_dir

    def sdk_path(v = version)
      (@sdk_path ||= {}).fetch(v.to_s) do |key|
        opts = []
        # First query Xcode itself
        opts << Utils.popen_read(locate("xcodebuild"), "-version", "-sdk", "macosx#{v}", "Path").chomp
        # Xcode.prefix is pretty smart, so lets look inside to find the sdk
        opts << "#{Xcode.prefix}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX#{v}.sdk"
        # Xcode < 4.3 style
        opts << "/Developer/SDKs/MacOSX#{v}.sdk"
        @sdk_path[key] = opts.map { |a| Pathname.new(a) }.detect(&:directory?)
      end
    end # sdk_path

    def default_cc
      cc = locate "cc"
      cc.realpath.basename.to_s rescue nil
    end

    def default_compiler
      case default_cc
        # if GCC 4.2 is installed, e.g. via Tigerbrew, prefer it
        # over the system's GCC 4.0
        when /^gcc-4.0/ then gcc_42_build_version ? :gcc : :gcc_4_0
        when /^gcc-4.2/ then :gcc
        when /^llvm/ then :llvm
        when "clang" then :clang
        else # guess :(
          if    Xcode.version >= "4.3" then :clang
          elsif Xcode.version >= "4.2" then :llvm
          else :gcc
          end
      end
    end # default_compiler

    def gcc_40_build_version
      @gcc_40_build_version ||=
        if (path = locate("gcc-4.0"))
          `#{path} --version`[/build (\d{4,})/, 1].to_i
        end
    end # gcc_40_build_version
    alias_method :gcc_4_0_build_version, :gcc_40_build_version

    def gcc_42_build_version
      @gcc_42_build_version ||=
        begin
          gcc = MacOS.locate("gcc-4.2") || OPTDIR/'apple-gcc42/bin/gcc-4.2'
          `#{gcc} --version`[/build (\d{4,})/, 1].to_i \
                        if gcc.exist? and gcc.realpath.basename.to_s !~ /^llvm/
        end
    end # gcc_42_build_version
    alias_method :gcc_build_version, :gcc_42_build_version

    def llvm_build_version
      @llvm_build_version ||=
        if (path = locate("llvm-gcc")) and path.realpath.basename.to_s !~ /^clang/
          `#{path} --version`[/LLVM build (\d{4,})/, 1].to_i
        end
    end # llvm_build_version

    def clang_version
      @clang_version ||=
        if (path = locate("clang"))
          `#{path} --version`[/(?:clang|LLVM) version (\d\.\d)/, 1]
        end
    end # clang_version

    def clang_build_version
      @clang_build_version ||=
        if (path = locate("clang"))
          `#{path} --version`[/clang-(\d{2,})/, 1].to_i
        end
    end # clang_build_version

    def non_apple_gcc_version(cc)
      (@non_apple_gcc_version ||= {}).fetch(cc) do
          path = OPTDIR/'gcc/bin/cc'
          path = locate(cc) unless path.exist?
          version = `#{path} --version`[/gcc(?:-\d\d?(?:\.\d)? \(.+\))? (\d\d?\.\d\.\d)/, 1] if path
          @non_apple_gcc_version[cc] = version
        end
    end # non_apple_gcc_version

    def clear_version_cache
      @gcc_40_build_version = @gcc_42_build_version = @llvm_build_version = nil
      @clang_version = @clang_build_version = nil
      @non_apple_gcc_version = {}
    end

    # See these issues for some history:
    # https://github.com/Homebrew/homebrew/issues/13
    # https://github.com/Homebrew/homebrew/issues/41
    # https://github.com/Homebrew/homebrew/issues/48
    def macports_or_fink
      paths = []
      # First look in the path because MacPorts is relocatable and Fink
      # may become relocatable in the future.
      %w[port fink].each do |ponk|
        path = which(ponk)
        paths << path unless path.nil?
      end
      # Look in the standard locations, because even if port or fink are
      # not in the path they can still break builds if the build scripts
      # have these paths baked in.
      %w[/sw/bin/fink /opt/local/bin/port].each do |ponk|
        path = Pathname.new(ponk)
        paths << path if path.exist?
      end
      # Finally, some users make their MacPorts or Fink directories
      # read-only in order to try out Homebrew, but this doesn't work as
      # some build scripts error out when trying to read from these now
      # unreadable paths.
      %w[/sw /opt/local].map { |p| Pathname.new(p) }.each do |path|
        paths << path if path.exist? && !path.readable?
      end

      paths.uniq
    end # macports_or_fink

    def preferred_arch
      prefer_64_bit? ? Hardware::CPU.arch_64_bit : Hardware::CPU.arch_32_bit
    end

    def preferred_arch_as_list
      [preferred_arch].extend(ArchitectureListExtension)
    end

    def counterpart_arch
      case preferred_arch
        when :arm64  then :x86_64
        when :i386   then :ppc
        when :ppc    then :i386
        when :ppc64  then :x86_64
        when :x86_64 then (version >= :catalina ? :arm64 : :ppc64)
        else :dunno
      end
    end # counterpart_arch

    def counterpart_type(main_type)
      case main_type
        when :arm, :ppc then :intel
        when :intel then (version >= :catalina ? :arm : :ppc)
        else :dunno
      end
    end # counterpart_type

    STANDARD_COMPILERS = {
      "2.0"   => { :gcc_40_build => 4061 },
      "2.5"   => { :gcc_40_build => 5370 },
      "3.1.4" => { :gcc_40_build => 5493, :gcc_42_build => 5577 },
      "3.2.6" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "1.7", :clang_build => 77 },
      "4.0"   => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
      "4.0.1" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
      "4.0.2" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
      "4.2"   => { :llvm_build => 2336, :clang => "3.0", :clang_build => 211 },
      "4.3"   => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
      "4.3.1" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
      "4.3.2" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
      "4.3.3" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
      "4.4"   => { :llvm_build => 2336, :clang => "4.0", :clang_build => 421 },
      "4.4.1" => { :llvm_build => 2336, :clang => "4.0", :clang_build => 421 },
      "4.5"   => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 },
      "4.5.1" => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 },
      "4.5.2" => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 },
      "4.6"   => { :llvm_build => 2336, :clang => "4.2", :clang_build => 425 },
      "4.6.1" => { :llvm_build => 2336, :clang => "4.2", :clang_build => 425 },
      "4.6.2" => { :llvm_build => 2336, :clang => "4.2", :clang_build => 425 },
      "4.6.3" => { :llvm_build => 2336, :clang => "4.2", :clang_build => 425 },
      "5.0"   => { :clang => "5.0", :clang_build => 500 },
      "5.0.1" => { :clang => "5.0", :clang_build => 500 },
      "5.0.2" => { :clang => "5.0", :clang_build => 500 },
      "5.1"   => { :clang => "5.1", :clang_build => 503 },
      "5.1.1" => { :clang => "5.1", :clang_build => 503 },
      "6.0"   => { :clang => "6.0", :clang_build => 600 },
      "6.0.1" => { :clang => "6.0", :clang_build => 600 },
      "6.1"   => { :clang => "6.0", :clang_build => 600 },
      "6.1.1" => { :clang => "6.0", :clang_build => 600 },
      "6.2"   => { :clang => "6.0", :clang_build => 600 },
      "6.3"   => { :clang => "6.1", :clang_build => 602 },
      "6.3.1" => { :clang => "6.1", :clang_build => 602 },
      "6.3.2" => { :clang => "6.1", :clang_build => 602 },
      "6.4"   => { :clang => "6.1", :clang_build => 602 },
      "7.0"   => { :clang => "7.0", :clang_build => 700 }
    }.freeze

    def compilers_standard?
      STANDARD_COMPILERS.fetch(Xcode.version.to_s).all? do |method, build|
        send(:"#{method}_version") == build
      end
    rescue IndexError
      onoe <<-EOS.undent
        Tigerbrew doesn't know what compiler versions ship with your version
        of Xcode (#{Xcode.version}). Please `brew update` and if that doesn't help, file
        an issue with the output of `brew --config`:
          https://github.com/mistydemeo/tigerbrew/issues

        Note that we only track stable, released versions of Xcode.

        Thanks!
      EOS
    end # compilers_standard?

    def app_with_bundle_id(*ids)
      path = mdfind(*ids).first
      Pathname.new(path) unless path.nil? || path.empty?
    end

    def mdfind(*ids)
      return [] unless OS.mac?
      (@mdfind ||= {}).fetch(ids) do
        @mdfind[ids] = Utils.popen_read("/usr/bin/mdfind", mdfind_query(*ids)).split("\n")
      end
    end # mdfind

    def pkgutil_info(id)
      (@pkginfo ||= {}).fetch(id) do |key|
        @pkginfo[key] = Utils.popen_read("/usr/sbin/pkgutil", "--pkg-info", key).strip
      end
    end

    def mdfind_query(*ids)
      ids.map! { |id| "kMDItemCFBundleIdentifier == #{id}" }.join(" || ")
    end
  end # ::MacOS
end # OS
