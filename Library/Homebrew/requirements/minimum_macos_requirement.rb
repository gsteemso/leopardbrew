require "requirement"

class MinimumMacOSRequirement < Requirement
  fatal true

  def initialize(tags)
    @version = MacOS::Version.new(Array(tags).first)
    super
  end

  satisfy(:build_env => false) { MacOS.version >= @version }

  def message; "Mac OS #{@version.pretty_name} or newer is required."; end
end # MinimumMacOSRequirement
