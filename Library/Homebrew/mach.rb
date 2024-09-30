module ArchitectureListExtension
  # @private
  def fat?; length > 1; end

  # @private
  def intel_universal?
    intersects_all?(Hardware::CPU::INTEL_32BIT_ARCHS, Hardware::CPU::INTEL_64BIT_ARCHS)
  end

  # @private
  def ppc_universal?
    intersects_all?(Hardware::CPU::PPC_32BIT_ARCHS, Hardware::CPU::PPC_64BIT_ARCHS)
  end

  # Old-style 32-bit PPC/Intel universal, e.g. ppc7400 and i386
  # @private
  def cross_universal?
    intersects_all?(Hardware::CPU::PPC_32BIT_ARCHS, Hardware::CPU::INTEL_32BIT_ARCHS)
  end

  # @private
  def universal?; intel_universal? || ppc_universal? || cross_universal?; end

  def ppc?
    (Hardware::CPU::PPC_32BIT_ARCHS+Hardware::CPU::PPC_64BIT_ARCHS).any? { |a| self.include? a }
  end

#  # @private
#  def remove_ppc!
#    (Hardware::CPU::PPC_32BIT_ARCHS+Hardware::CPU::PPC_64BIT_ARCHS).each { |a| delete a }
#  end

  def as_arch_flags; collect { |a| "-arch #{a}" }.join(" "); end

  def as_cmake_arch_flags; join(";"); end

  protected

  def intersects_all?(*set); set.all? { |archset| archset.any? { |a| self.include? a } }; end
end

# only useable when included in Pathname
module MachO
  # @private
  MACH_SIGNATURES = {
    'cafebabe' => :FAT_MAGIC,
    'feedface' => :MH_MAGIC,
    'feedfacf' => :MH_MAGIC_64,
  }.freeze

  MACH_FILE_TYPE = {
     1 => :MH_OBJECT,       # Relatively small object‐code file
     2 => :MH_EXECUTE,      # Executable
     3 => :MH_FVMLIB,       # Fixed VM shared library file
     4 => :MH_CORE,         # Core dump
     5 => :MH_PRELOAD,      # Preloaded executable
     6 => :MH_DYLIB,        # Dynamically bound shared library
     7 => :MH_DYLINKER,     # Dynamic link editor (LD itself)
     8 => :MH_BUNDLE,       # Dynamically bound object‐code bundle
     9 => :MH_DYLIB_STUB,   # Shared library stub for static linking only (no section contents)
    10 => :MH_DSYM,         # “companion file with only debug sections”
    11 => :MH_KEXT_BUNDLE,  # X86_64 kernel extension
    12 => :MH_FILESET       # “set of Mach‐Os”
  }.freeze

  # @private
  OTOOL_RX = /\t(.*) \(compatibility version (?:\d+\.)*\d+, current version (?:\d+\.)*\d+\)/

  # Mach-O binary methods, see:
  # /usr/include/mach-o/loader.h
  # /usr/include/mach-o/fat.h
  # @private
  def mach_data
    @mach_data ||= begin
        offsets = []
        mach_data = []

        if sig = mach_o_signature?
          if sig == :FAT_MAGIC
            fat_count.times do |i|
              # The second quad is the number of `struct fat_arch` in the file.
              # Each `struct fat_arch` is 5 quads (20 bytes); the `offset` member
              # is the 3rd (8 bytes into the struct), with an additional 8 byte
              # offset due to the 2-quad `struct fat_header` at the beginning of
              # the file.
              offsets << read(4, 20*i + 16).unpack("N").first
            end
          else offsets << 0; end  # single arch
        else raise "Not a Mach-O binary."
        end

        offsets.each do |offset|
          arch = \
            if (sig = binread(4, offset).unpack('H8').first) == 'feedface' and (cputype_flags = binread(1, offset + 4)) == "\x00"
              if (cputype = binread(3, offset + 5).unpack('H6').first) == '000007' then :i386
              elsif cputype == '00000c' then :arm
              elsif cputype == '000012' then :ppc
              else :dunno; end
            elsif sig == 'feedfacf'
              if (cputype = binread(3, offset + 5)) == '000007' and cputype_flags == "\x01" then :x86_64
              elsif cputype == '00000c'
                if cputype_flags == "\x01" then :arm64
                elsif cputype_flags == "\x02" then :arm64_32
                else :dunno; end
              elsif cputype == '000012' and cputype_flags == "\x01" then :ppc64
              else :dunno; end
            end # determine arch
          mach_data << { :arch => arch, :type => MACH_FILE_TYPE[binread(4, offset + 12).unpack('N').first] }
        end # each offset
        mach_data
      rescue # from error during mach_data construction
        []
      end # mach_data construction
  end

  def archs; mach_data.map { |m| m.fetch :arch }.extend(ArchitectureListExtension); end

  def arch
    case archs.length
      when 0 then :dunno
      when 1 then archs.first
      else :universal
    end
  end

  def universal?; arch == :universal; end

  def i386?; arch == :i386; end

  def x86_64?; arch == :x86_64; end

  def ppc?; arch == :ppc; end

  def ppc64?; arch == :ppc64; end

  # @private
  def dylib?; mach_data.any? { |m| m.fetch(:type) == :MH_DYLIB }; end

  # @private
  def mach_o_executable?; mach_data.any? { |m| m.fetch(:type) == :MH_EXECUTE }; end

  # @private
  def mach_o_bundle?; mach_data.any? { |m| m.fetch(:type) == :MH_BUNDLE }; end

  # This also finds signatures within Ar archives.
  # The universal‐binary file signature is also used by Java files, so do extra
  #   sanity‐checking for that case.  If there are an implausibly large number of
  #   architectures, it is unlikely to be a real fat binary; Java files, for example,
  #   will produce a figure well in excess of 60 thousand.  Assume up to 7
  #   architectures, in case we ever handle ARM binaries as well:  ppc, ppc64, i386,
  #   x86_64, arm, arm64, arm64_32.
  def mach_o_signature?
    if file? and
        (size >= 28 and (sig = MACH_SIGNATURES[binread(4).unpack('H8').first]) and fat_count <= 7) or
        (binread(8) == "!<arch>\x0a" and size >= 72 and
         (binread(16, 8) !~ %r|^#1/\d+|   and (sig = MACH_SIGNATURES[binread(4, 68).unpack('H8').first])) or
         (binread(16, 8) =~ %r|^#1/(\d+)| and (sig = MACH_SIGNATURES[binread(4, 68+($1.to_i)).unpack('H8').first])))
      sig
    end
  end # mach_o_signature

  # Only call this if we already know it’s a universal binary!
  # @private
  def fat_count; binread(4,4).unpack('N').first; end

  # @private
  class Metadata
    attr_reader :path, :dylib_id, :dylibs

    def initialize(path)
      @path = path
      @dylib_id, @dylibs = parse_otool_L_output
    end

    def parse_otool_L_output
      ENV["HOMEBREW_MACH_O_FILE"] = path.expand_path.to_s
      libs = `#{MacOS.otool} -L "$HOMEBREW_MACH_O_FILE"`.split("\n")
      unless $?.success?
        raise ErrorDuringExecution.new(MacOS.otool,
          ["-L", ENV["HOMEBREW_MACH_O_FILE"]])
      end

      libs.shift # first line is the filename

      id = libs.shift[OTOOL_RX, 1] if path.dylib?
      libs.map! { |lib| lib[OTOOL_RX, 1] }.compact!

      return id, libs
    ensure
      ENV.delete "HOMEBREW_MACH_O_FILE"
    end
  end

  # @private
  def mach_metadata; @mach_metadata ||= Metadata.new(self); end

  # Returns an array containing all dynamically-linked libraries, based on the
  # output of otool. This returns the install names, so these are not guaranteed
  # to be absolute paths.
  # Returns an empty array both for software that links against no libraries,
  # and for non-mach objects.
  # @private
  def dynamically_linked_libraries; mach_metadata.dylibs; end

  # @private
  def dylib_id; mach_metadata.dylib_id; end
end
