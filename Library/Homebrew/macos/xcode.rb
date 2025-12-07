# This file is loaded before `global.rb`, so must eschew many brew‐isms at eval time.

module MacOS
  module Xcode
    extend self

    V4_BUNDLE_ID = "com.apple.dt.Xcode"
    V3_BUNDLE_ID = "com.apple.Xcode"

    LATEST_XCODE = {
      :tahoe         => '26.0',
      :sequoia       => '16.4',
      :sonoma        => '16.2',
      :ventura       => '15.2',
      :monterey      => '14.2',
      :big_sur       => '13.2.1',
      :catalina      => '12.4',
      :mojave        => '11.3.1',
      :high_sierra   => '10.1',
      :sierra        => '9.2',
      :el_capitan    => '8.2.1',
      :yosemite      => '6.4',
      :mavericks     => '6.2',
      :mountain_lion => '5.1.1',
      :lion          => '4.6.3',
      :snow_leopard  => '3.2.6',
      :leopard       => '3.1.4',
      :tiger         => '2.5',
      :panther       => '0',
    }.freeze

    # Ask Spotlight where Xcode is.  If the user didn’t install the helper tools, and put Xcode in an unconventional place, this is
    # our only option.  See (https://superuser.com/questions/390757).
    def bundle_path; MacOS.app_with_bundle_id(V4_BUNDLE_ID, V3_BUNDLE_ID); end

    def default_prefix?
      if version < "4.3"
        %r{^/Developer} === prefix
      else
        %r{^/Applications/Xcode.app} === prefix
      end
    end # default_prefix?

    def installed?; not prefix.nil?; end

    def latest_version; (found = LATEST_XCODE[MacOS.codename]) ? found : raise("Mac OS “#{MacOS.version}” is unknown"); end

    def outdated?; version < latest_version; end

    def prefix
      dir = MacOS.active_developer_dir
      @prefix ||= (dir.nil? or dir.to_s == CLT::MAVERICKS_PKG_PATH or not dir.directory?) \
        ? if (path = bundle_path) then path/'Contents/Developer'; end \
        : dir
    end # prefix

    def provides_autotools?; (version < "4.3") && (version > "2.5"); end
    # Xcode 2.5's autotools are too old to rely on at this point

    def provides_gcc?; version < "4.3"; end

    def provides_cvs?; version < "5.0"; end

    def toolchain_path
      Pathname.new("#{prefix}/Toolchains/XcodeDefault.xctoolchain") if installed? and version >= "4.3"
    end

    # This may return nil or a version string guessed based on the compiler, so don’t use it to check if Xcode is installed.
    def version; @version ||= uncached_version; end

    def without_clt?; installed? and version >= "4.3" and not MacOS::CLT.installed?; end

    private

    # This had to be factored out as you can’t cache a block’s value when you return from the middle, which we do many times here.
    def uncached_version
      return nil unless MacOS::Xcode.installed? or MacOS::CLT.installed?
      %W[#{prefix}/usr/bin/xcodebuild #{which("xcodebuild")}].uniq.each do |path|
        if File.file? path
          Utils.popen_read(path, "-version") =~ /Xcode (\d(\.\d)*)/
          return $1 if $1

          # Xcode 2.x's xcodebuild has a different version string
          Utils.popen_read(path, '-version', '2>/dev/null') =~ /DevToolsCore-(\d+\.\d)/
          case $1
            when "798.0" then return "2.5"
            when "515.0" then return "2.0"
          end
        end
      end
    end # uncached_version
  end # Xcode

  module CLT
    extend self

    STANDALONE_PKG_ID = "com.apple.pkg.DeveloperToolsCLILeo"
    FROM_XCODE_PKG_ID = "com.apple.pkg.DeveloperToolsCLI"
    MAVERICKS_PKG_ID = "com.apple.pkg.CLTools_Executables"
    MAVERICKS_NEW_PKG_ID = "com.apple.pkg.CLTools_Base" # obsolete
    MAVERICKS_PKG_PATH = "/Library/Developer/CommandLineTools"

    LATEST_CLANG = {
        :tahoe         => '1700.3.19.1',
        :sequoia       => '1700.13.5',
        :sonoma        => '1600.0.26.6',
        :ventura       => '1500.1.0.2.5',
        :monterey      => '1400.0.29.202',
        :big_sur       => '1300.0.29.30',
        :catalina      => '1200.0.32.29',
        :mojave        => '1100.0.33.17',
        :high_sierra   => '1000.10.44.2',
        :sierra        => '900.0.39.2',
        :el_capitan    => '800.0.42.1',
        :yosemite      => '602.0.53',
        :mavericks     => '600.0.57',
        :mountain_lion => '503.0.40',
        :lion          => '425.0.28',
        :snow_leopard  => '0',
        :leopard       => '0',
        :tiger         => '0',
        :panther       => '0',
      }.freeze

    # Returns true even if outdated tools are installed, e.g. tools from Xcode 4.x on 10.9
    def installed?; !!detect_version; end

    def latest_clang_version; (found = LATEST_CLANG[MacOS.version]) ? found : raise("Mac OS “#{MacOS.version}” is unknown"); end

    def outdated?
      vers = Utils.popen_read("#{MAVERICKS_PKG_PATH if MacOS.version >= :mavericks}/usr/bin/clang", '--version')
      vers = vers[/clang-(\d+\.\d+\.\d+(\.\d+)?)/, 1] || "0"
      vers < latest_clang_version
    end

    # Version string (a pretty long one) of the CLT package.  Note that installing it differently yields different version numbers.
    def version; @version ||= detect_version; end

    def detect_version
      # CLT wasn’t a distinct entity pre-4.3, and pkgutil doesn’t exist at all on Tiger, so just call it installed if Xcode is.
      return MacOS::Xcode.version if MacOS::Xcode.installed? and MacOS::Xcode.version < '3.0'

      [MAVERICKS_PKG_ID, MAVERICKS_NEW_PKG_ID, STANDALONE_PKG_ID, FROM_XCODE_PKG_ID].find do |id|
        if MacOS.version >= :mavericks
          next unless File.exists?("#{MAVERICKS_PKG_PATH}/usr/bin/clang")
        end
        version = MacOS.pkgutil_info(id)[/version: (.+)$/, 1]
        return version if version
      end
    end # CLT::detect_version
  end # CLT
end # MacOS
