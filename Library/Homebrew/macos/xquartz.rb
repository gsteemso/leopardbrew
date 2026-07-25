module MacOS
  X11 = XQuartz = Module.new

  module XQuartz
    extend self

    FORGE_BUNDLE_ID = 'org.macosforge.xquartz.X11'
    APPLE_BUNDLE_ID = 'org.x.X11'
    FORGE_PKG_ID = 'org.macosforge.xquartz.pkg'

    PKGINFO_VERSION_MAP = {
      '2.6.34' => '2.6.3',
      '2.7.4'  => '2.7.0',
      '2.7.14' => '2.7.1',
      '2.7.28' => '2.7.2',
      '2.7.32' => '2.7.3',
      '2.7.43' => '2.7.4',
      '2.7.50' => '2.7.5_rc1',
      '2.7.51' => '2.7.5_rc2',
      '2.7.52' => '2.7.5_rc3',
      '2.7.53' => '2.7.5_rc4',
      '2.7.54' => '2.7.5',
      '2.7.61' => '2.7.6',
      '2.7.73' => '2.7.7'
    }.freeze

    # This returns the version number of XQuartz, not of the upstream X.org.  The X11.app distributed by Apple is also XQuartz, and
    # therefore covered by this method.
    def version; @version ||= detect_version; end

    private

    def detect_version
      ((path = bundle_path) and path.exists? and (version = version_from_mdls(path))) ? version              \
        : ['/usr/X11', '/usr/X11R6'].include?(prefix.to_s)                            ? guess_system_version \
        :                                                                               version_from_pkgutil
    end

    def version_from_mdls(path)
      version = Utils.popen_read('/usr/bin/mdls', '-raw', '-nullMarker', '', '-name', 'kMDItemVersion', path.to_s).strip
      version unless version.empty?
    end

    # The XQuartz that Apple shipped in OS X through 10.7 does not have a pkg-util entry, so if Spotlight indexing is disabled we
    # must make an educated guess as to what version is installed.
    def guess_system_version
      case MacOS.version
        when :tiger        then '1.1.3'
        when :leopard      then '2.1.6'
        when :snow_leopard then '2.3.6'
        when :lion         then '2.6.3'
        else 'dunno'
      end
    end # guess_system_version

    # Upstream XQuartz *does* have a pkg-info entry, so if we can't get it from mdls, we can try pkgutil.  This is very slow.
    def version_from_pkgutil
      str = MacOS.pkgutil_info(FORGE_PKG_ID)[/version: (\d\.\d\.\d+)$/, 1]
      PKGINFO_VERSION_MAP.fetch(str, str)
    end

    public

    # https://xquartz.org/trac/wiki
    # https://xquartz.org/trac/wiki/Releases
    def latest_version
      case MacOS.version
        when :panther, :tiger then '1.1.3'
        when :leopard         then '2.6.3'
        when :snow_leopard, :lion,
             :mountain_lion   then '2.7.11'
        else                       '2.8.5'
      end
    end # latest_version

    def bundle_path; MacOS.app_with_bundle_id(FORGE_BUNDLE_ID, APPLE_BUNDLE_ID); end

    def provided_by_apple?
      return true if prefix.to_s == '/usr/X11R6'  # Tiger X11 has no bundle id, but this old directory is only from Apple
      [FORGE_BUNDLE_ID, APPLE_BUNDLE_ID].find{ |id| MacOS.app_with_bundle_id(id) } == APPLE_BUNDLE_ID
    end

    # FIXME:  This should really be private, but for compatibility reasons it must remain public.  New code should use #bin, #lib,
    # and #include (below) instead, as those account for Xcode-only systems.
    def prefix
      @prefix ||= File.exists?('/opt/X11/lib/libpng.dylib')     ? Pathname('/opt/X11') \
                  : File.exists?('/usr/X11/lib/libpng.dylib')   ? Pathname('/usr/X11') \
                  : File.exists?('/usr/X11R6/lib/libX11.dylib') ? Pathname('/usr/X11R6') : nil  # X11 doesn’t have libpng on Tiger
    end # prefix

    def installed?; !!version and !!prefix; end

    # If XQuartz and/or the CLT are installed, headers will be found under /opt/X11/include or /usr/X11/include.  For Xcode-only
    # systems, they are found in the SDK, so we use sdk_path for both the headers and libraries.  Confusingly, executables (e.g.
    # config scripts) are only found under /opt/X11/bin or /usr/X11/bin in all cases.
    def effective_prefix; (provided_by_apple? and Xcode.without_clt?) ? Pathname("#{MacOS.sdk_path}/usr/X11") : prefix; end

    def bin; prefix/'bin'; end

    def include; effective_prefix/'include'; end

    def lib; effective_prefix/'lib'; end

    def share; prefix/'share'; end
  end # XQuartz
end # MacOS
