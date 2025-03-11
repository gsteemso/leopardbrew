# This file is loaded before `global.rb`, so must eschew many Homebrew‐isms at
# eval time.

POWERPC_ARCHS = [:ppc, :ppc64].freeze;

INTEL_ARCHS = [:i386, :x86_64, :x86_64h].freeze;

INTEL_ARCHS_64 = [:x86_64, :x86_64h].freeze;

ARM_ARCHS = [:arm64e].freeze

module ArchitectureListExtension  # applicable to arrays of architecture symbols
  # @private
  def fat?; length > 1; end
  alias_method :universal?, :fat?

  # @private
  def fat_intel?; includes? :i386 and intersects? INTEL_ARCHS_64; end
  def fat_powerpc?; includes? :ppc and includes? :ppc64; end

  # @private
  # Universal Binaries, original flavour:  Usually old-style 32-bit PowerPC/
  # Intel, e.g. ppc + i386, but can also be Leopard‐style quad fat binaries, or
  # in some cases triple fat binaries with no ppc64 slice.  (Other combinations
  # are not generally found in the wild.)
  def universal_1?; intersects_all?(POWERPC_ARCHS, INTEL_ARCHS_64); end
  def universal_2?; intersects_all?(INTEL_ARCHS_64, ARM_ARCHS); end
  def cross_universal?; universal_1? or universal_2?; end

  # @private
  def powerpc?; intersects? POWERPC_ARCHS; end
  def intel?; intersects? INTEL_ARCHS; end
  def arm?; intersects? ARM_ARCHS; end

  def as_arch_flags; map{ |a| "-arch #{a.to_s}" }.join(' '); end

  def as_cmake_arch_flags; map(&:to_s).join(';'); end

  def as_build_archs; map(&:to_s).join(' '); end

  protected

  def intersects?(aset); aset.any?{ |a| includes? a }; end

  def intersects_all?(*asets); asets.all?{ |aset| intersects? aset }; end
end # ArchitectureListExtension

# only useable when included in Pathname
module MachO
  # @private
  AR_MAGIC = "!<arch>\n".freeze
  AR_MEMBER_HDR_SIZE = 60.freeze

  # @private
  FILE_SIGNATURES = {
    0xcafebabe => :FAT_MAGIC,
    0xfeedface => :MH_MAGIC,
    0xfeedfacf => :MH_MAGIC_64,
  }.freeze
  MACH_FILE_TYPE = {
    0x00000001 => :MH_OBJECT,       # Relatively small object‐code file
    0x00000002 => :MH_EXECUTE,      # Executable
    0x00000003 => :MH_FVMLIB,       # Fixed VM shared library file
    0x00000004 => :MH_CORE,         # Core dump
    0x00000005 => :MH_PRELOAD,      # Preloaded executable
    0x00000006 => :MH_DYLIB,        # Dynamically bound shared library
    0x00000007 => :MH_DYLINKER,     # Dynamic link editor (LD itself)
    0x00000008 => :MH_BUNDLE,       # Dynamically bound object‐code bundle
    0x00000009 => :MH_DYLIB_STUB,   # Shared library stub – static linking only (no section contents)
    0x0000000a => :MH_DSYM,         # “companion file with only debug sections”
    0x0000000b => :MH_KEXT_BUNDLE,  # X86_64 kernel extension
    0x0000000c => :MH_FILESET       # “set of Mach‐Os”
  }.freeze

  # Mach-O binary methods, see:
  # <mach-o/loader.h>
  # <mach-o/fat.h>
  # @private
  def mach_data
    @mach_data ||= \
      begin
        offsets = []
        data = []
        if candidate = ar_sigseek_from(0) then offsets << candidate
        elsif sig = mach_o_signature_at?(0)
          if sig == :FAT_MAGIC
            if (fct = fat_count_at(0)) and fct > 0
              fct.times do |i|
                # The second uint32 is the number of `struct fat_arch` in the file.  Each `struct
                # fat_arch` is 5 uint32 (20 octets); the `offset` member is the 3rd (8 octets into
                # the struct), with an additional 8‐octet offset due to the two-uint32 `struct
                # fat_header` at the beginning of the file.
                candidate = binread(4, 16 + 20*i).unpack("N").first
                offsets << (ar_sigseek_from(candidate) or candidate)
              end
            end
          else offsets << 0 # single arch (:MH_MAGIC or :MH_MAGIC_64)
          end # mach-O signature?
        end # signatures?
        offsets.each do |offset|
          if size >= (offset + 16)  # Mach headers:  We only care about the first 4 uint32 (16
            # octets) of the 7 in the header.  The first (at offset + 0) is the signature, the
            # second (at offset + 4) is the CPU type (with flags in the high‐order octet), the
            # third (at offset + 8) is the CPU subtype (with flags in the high‐order octet), and
            # the fourth (at offset + 12) is the Mach file type.
            sig, cputype, cpu_subtype, mach_filetype = binread(16, offset).unpack('NNNN')
            sig = FILE_SIGNATURES[sig & 0xfffffffe]
            arch = if sig == :MH_MAGIC
                     case cputype
                       when 0x00000007 then :i386
                       when 0x00000012 then :ppc
                       when 0x01000007
                         cpu_subtype & 0x00ffffff == 8 ? :x86_64h : :x86_64
                       when 0x0100000c then :arm64e
                       when 0x01000012 then :ppc64
                       else :dunno
                     end
                   end # determine arch
            data << { :arch => arch,
                      :cpu_subtype => cpu_subtype,
                      :type => MACH_FILE_TYPE[mach_filetype]
            } unless arch == :dunno
          end # valid offset
        end # each offset
        data.uniq
      rescue  # from error during @mach_data construction
        []
      end # @mach_data construction
  end # mach_data

  def archs
    @archs ||= mach_data.map{ |m| m.fetch :arch, :dunno }.uniq.extend(ArchitectureListExtension)
  end

  def arch
    @arch ||= case archs.length
                when 0 then :dunno
                when 1 then archs.first
                else :fat
              end
  end # arch

  def fat?; archs.fat?; end
  def powerpc?; archs.powerpc?; end
  def intel?; archs.intel?; end
  def arm?; archs.arm?; end

  # @private
  def dylib?; mach_data.any?{ |m| m.fetch(:type) == :MH_DYLIB }; end

  # @private
  def mach_o_executable?; mach_data.any?{ |m| m.fetch(:type) == :MH_EXECUTE }; end

  # @private
  def mach_o_bundle?; mach_data.any?{ |m| m.fetch(:type) == :MH_BUNDLE }; end

  def tracked_mach_o?
    mach_data.any?{ |m| mtype = m.fetch(:type)
      [:MH_EXECUTE, :MH_DYLIB, :MH_BUNDLE].any?{ |mh| mh == mtype }
    }
  end

  # The universal‐binary file signature is the same as that of Java files, so we do extra sanity‐
  # checking for that case.  If there are an implausibly large number of architectures, it is
  # unlikely to be a real fat binary; Java files, for example, will produce a figure well in excess
  # of 60 thousand.  Assume up to 30 architectures, allowing for ARM binaries (some system‐library
  # stubs contain one slice for each of the possible iPhone architectures!) and slots for future
  # expansion.  At present we only expect:  ppc, i386, ppc64, x86_64, x86_64h, arm64e.
  def mach_o_signature_at?(offset)
    sig = nil unless (file? and size >= (offset + 4) and
                (sig = FILE_SIGNATURES[binread(4, offset).unpack('N').first]) and
                (sig != :FAT_MAGIC or (fct = fat_count_at(offset) and fct <= 30)))
    sig
  end # mach_o_signature_at?

  # Only call this if we already know it’s a fat binary!
  # @private
  def fat_count_at(offset); size > (offset + 8) and binread(4, offset + 4).unpack('N').first; end

  # ‘ar’ archive binary stuff.  See <ar.h> and ar(5).

  def ar_signature_at?(offset)
    file? and size >= (offset + 8) and (binread(8, offset).unpack('a8').first == AR_MAGIC)
  end

  # In an ‘ar’ archive, finds the start of the current member’s sub‐file and walks to the next
  #   member.  Returns a list:  [offset of signature, offset of next header].  The latter is ‘nil’
  #   at the end of the archive; the former is also ‘nil’ if the current member is stunted enough.
  # @private
  def ar_walk_from(initial_offset)
    return [nil, nil] if size <= (body_offset = initial_offset + AR_MEMBER_HDR_SIZE)
    header = binread(AR_MEMBER_HDR_SIZE, initial_offset)
    extent = (header.b[0, 16] =~ %r{^#1/(\d+)} ? $1.to_i : 0)   # extended name after header block?
    startpoint = body_offset + extent                           # → extent has its size
    return [nil, nil] if size < (startpoint + 8)
    extent = (header.b[48, 10] =~ %r{^(\d+)} ? $1.to_i : 0)     # now, extent == the payload size
    endpoint = body_offset + extent
    endpoint += (endpoint & 1)                                  # pad to an even number of bytes

    [startpoint, (size > endpoint ? endpoint : nil)]
  end # ar_walk_from

  # Returns either the offset of the next valid Mach-O ‘ar’ member, or ‘nil’.
  # @private
  def ar_sigseek_from(offset)
    return nil unless ar_signature_at?(offset)
    offset += 8
    while offset
      candidate, offset = ar_walk_from(offset)
      break unless candidate
      next if ar_signature_at?(candidate)                       # skip malformed data
      break if (sig = mach_o_signature_at?(candidate)) and      # stop @ 1st good signature
                sig != :FAT_MAGIC                               # skip malformed data
      candidate = nil
    end

    candidate
  end # ar_sigseek_from

  # @private
  class Metadata
    OTOOL_RX = /\t(.*) \(compatibility version (?:\d+\.)*\d+, current version (?:\d+\.)*\d+\)/

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
    end # parse_otool_L_output
  end # Mach::Metadata

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
end # MachO
