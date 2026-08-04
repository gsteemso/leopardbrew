require 'requirement'

class OsxfuseRequirement < Requirement
  fatal true
  default_formula 'osxfuse'
  cask 'osxfuse'
  download 'https://osxfuse'

  satisfy(:build_env => false) { Formula['osxfuse'].installed? or self.class.binary_osxfuse_installed? }

  def self.binary_osxfuse_installed?
    File.exists?('/usr/local/include/osxfuse/fuse.h') and not File.symlink?('/usr/local/include/osxfuse')
  end

  env do
    ENV.append_path 'PKG_CONFIG_PATH', HOMEBREW_REPOSITORY/'Library/ENV/pkgconfig/fuse'
  end
end

class NonBinaryOsxfuseRequirement < Requirement
  fatal true
  satisfy(:build_env => false) { HOMEBREW_PREFIX.to_s != '/usr/local' or not OsxfuseRequirement.binary_osxfuse_installed? }

  def message
    <<-EOS.undent
      osxfuse is already installed from the binary distribution and
      conflicts with this formula.
    EOS
  end
end
