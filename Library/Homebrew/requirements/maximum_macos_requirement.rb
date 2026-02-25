require "requirement"

class MaximumMacOSRequirement < Requirement
  fatal true

  def initialize(tags)
    @version = MacOS::Version.new(Array(tags).first)
    super
  end

  satisfy(:build_env => false) { MacOS.version <= @version }

  def message; "Mac OS #{@version.pretty_name} or older is required."; end
end # MaximumMacOSRequirement
