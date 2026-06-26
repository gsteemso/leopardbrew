# Used to annotate formulæ that don’t require compiling or cannot build bottle.
class BottleDisableReason
  def initialize(type, reason)
    @type = type
    @reason = reason
  end

  def unneeded?; @type == :unneeded; end

  def to_s; @type == :unneeded ? 'This formula doesn’t require compilation.' : @reason; end
end # BottleDisableReason

# Used to hide the complexities of juggling multiple potential checkpoint‐compression formats.
class CheckpointTarball
  EXTNAME = { :bzip2 => 'tbz2',
              :gzip  => 'tgz',
              :lzip  => 'tlz',
              :xz    => 'txz',
              :zstd  => 'zst',  }

  # tar -j:  (filter through bzip2.)
  #     -z:  (filter through gzip.)
  PACK = { :bzip2 => "safe_system TAR_PATH, '-cjf', file, *these_items"
           :gzip  => "safe_system TAR_PATH, '-czf', file, *these_items",
           :lzip  => "Utils.pipe_from_tar OPTDIR/'lzip/bin/lzip', file, *these_items",
           :xz    => "Utils.pipe_from_tar OPTDIR/'xz/bin/xz', file, *these_items",
           :zstd  => "safe_system OPTDIR/'zstd/bin/zstd', *these_items, '-o', file",   }

  # tar -i:  Ignore zeroed input blocks.  (Some malformed archives require this.)
  #     -m:  update Modification times, to avert spurious re`make`ing.
  #     -p:  restore Permissions.
  UNPACK = { :bzip2 => "safe_system TAR_PATH, '-xijmpf', file",
             :gzip  => "safe_system TAR_PATH, '-xizmpf', file",
             :lzip  => "Utils.pipe_to_untar OPTDIR/'lzip/bin/lzip', file, 'mp'",
             :xz    => "Utils.pipe_to_untar OPTDIR/'xz/bin/xz', file, 'mp'",
             :zstd  => "safe_system OPTDIR/'zstd/bin/zstd', '-d', file",         }

  attr_reader :file, :format

  def initialize(prefix, name)
    @prefix = prefix; @name = name
    files = Dir["#{prefix}/checkpoint-#{name}.*"]
    if (@exists = not files.empty?)
      @file = Pathname.new files.first
      @format = file.compression_type
    else
      @format = self.class.decide_format
      @file = Pathname.new "#{@prefix}/checkpoint-#{@name}.#{EXTNAME[format]}"
    end
  end # CheckpointTarball#initialize()

  def exists?; @exists; end

  def pack(*these_items); return if exists?; eval PACK[format]; end

  def unpack; return unless exists?; eval UNPACK[format]; end  # into the current directory

  def self.decide_format
    if    Formula['zstd' ].any_version_installed? then :zstd
    elsif Formula['lzip' ].any_version_installed? then :lzip
    elsif Formula['xz'   ].any_version_installed? then :xz
    elsif Formula['bzip2'].any_version_installed? or File.executable? '/usr/bin/bzip2' then :bzip2
    else :gzip
  end # CheckpointTarball::decide_format
end # CheckpointTarball

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
