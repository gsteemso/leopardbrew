require "requirement"

class MaximumMacOSRequirement < Requirement
  fatal true

  def initialize(tags)
    @version = MacOS::Version.new(tags.first)
    super
  end

  satisfy(:build_env => false) { MacOS.version <= @version }

  def message
    <<-EOS.undent
      Mac OS #{@version.pretty_name} or older is required.
    EOS
  end
end
