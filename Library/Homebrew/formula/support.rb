# Used to track formulae that cannot be installed at the same time
FormulaConflict = Struct.new(:name, :reason)

# Used to annotate formulæ that duplicate OS‐provided software or cause conflicts when linked in.
class KegOnlyReason
  def initialize(owner, reason, explanation)
    @owner = owner
    @reason = reason
    @explanation = explanation
  end

  def valid?
    case @reason
      when :insinuated                 then @owner.insinuation_defined?
      when :provided_pre_mountain_lion then MacOS.version < :mountain_lion
      when :provided_pre_mavericks     then MacOS.version < :mavericks
      when :provided_pre_el_capitan    then MacOS.version < :el_capitan
      when :provided_until_xcode43     then MacOS::Xcode.version < '4.3'
      when :provided_until_xcode5      then MacOS::Xcode.version < '5.0'
      else                                  true
    end
  end # KegOnlyReason#valid?

  def to_s
    return @explanation unless @explanation.empty?
    case @reason
      when :insinuated then <<-EOS.undent
          This software is insinuated into your system, and would be linked more than once
          (probably causing strange problems) if it weren’t keg‐only.
        EOS
      when :provided_by_mac_os, :provided_by_osx then <<-EOS.undent
          Mac OS already provides this software and installing another version in
          parallel can cause all kinds of trouble.
        EOS
      when :shadowed_by_mac_os, :shadowed_by_osx then <<-EOS.undent
          Mac OS provides similar software and installing this software in parallel
          can cause all kinds of trouble.
        EOS
      when :provided_pre_mountain_lion then 'Mac OS already provides this software in versions before Mountain Lion.'
      when :provided_pre_mavericks then 'Mac OS already provides this software in versions before Mavericks.'
      when :provided_pre_el_capitan then 'Mac OS already provides this software in versions before El Capitan.'
      when :provided_until_xcode43 then 'Xcode provides this software prior to version 4.3.'
      when :provided_until_xcode5 then 'Xcode provides this software prior to version 5.'
      else @reason
    end.strip
  end # KegOnlyReason#to_s
end # KegOnlyReason

# Used to annotate formulae that don’t require compiling or cannot build bottle.
class BottleDisableReason
  def initialize(type, reason)
    @type = type
    @reason = reason
  end

  def unneeded?; @type == :unneeded; end

  def to_s; @type == :unneeded ? 'This formula doesn’t require compilation.' : @reason; end
end # BottleDisableReason
