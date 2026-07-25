# This file is loaded before `global.rb`, so must eschew many brew‐isms at eval time.

module ArchitectureConstants
  POWERPC_ARCHS = [:ppc, :ppc64].freeze;

  INTEL_ARCHS = [:i386, :x86_64].freeze;

  ARM_ARCHS = [:arm64].freeze
end # ArchitectureConstants

module ALE  # ArchitectureListExtension:  Applicable to arrays of architecture symbols.
  include ArchitectureConstants

  def fat?; length > 1; end
  alias_method :universal?, :fat?

  def fat_intel?; includes? :i386 and includes? :x86_64; end
  def fat_powerpc?; includes? :ppc and includes? :ppc64; end

  # Universal Binaries, original flavour:  Usually old-style 32-bit PowerPC/Intel, e.g. ppc + i386, but might also be Leopard‐style
  # quad fat binaries, or Snow‐Leopard‐style triple fat binaries with no ppc64 slice.  (Other combinations are not usually found in
  # the wild, unless you count iOS binaries with multiple 32‐bit ARM slices.)
  def universal_1?; includes? :i386 and includes? :ppc; end
  def universal_2?; includes? :x86_64 and includes? :arm64; end

  def powerpc?; intersects? POWERPC_ARCHS; end
  def intel?; intersects? INTEL_ARCHS; end
  def arm?; intersects? ARM_ARCHS; end

  def _32b_subset; reject{ |a| a != :ppc and a != :i386 }.extend ALE; end
  def _64b_subset; reject{ |a| a == :ppc or  a == :i386 }.extend ALE; end

  def as_arch_flag_array; flat_map{ |a| ['-arch', a.to_s] }; end

  def as_arch_flags; as_arch_flag_array.join(' '); end

  def as_cmake_arch_flags; map(&:to_s).join(';'); end

  def as_build_archs; map(&:to_s).join(' '); end
end # ALE

module MachO  # only useable when included in Pathname
  # @private
  FILE_SIGNATURES = {
      0xcafebabe => :FAT_MAGIC,
      0xbebafeca => :FAT_CIGAM,
      0xcefaedfe => :MH_CIGAM,
      0xcffaedfe => :MH_CIGAM_64,
      0xfeedface => :MH_MAGIC,
      0xfeedfacf => :MH_MAGIC_64,
    }.freeze
  MACH_FILE_TYPE = {
      0x00000001 => :MH_OBJECT,       # Relatively small object‐code file
      0x00000002 => :MH_EXECUTE,      # Executable
      0x00000003 => :MH_FVMLIB,       # Fixed VM shared library file (obsolete)
      0x00000004 => :MH_CORE,         # Core dump
      0x00000005 => :MH_PRELOAD,      # Preloaded executable
      0x00000006 => :MH_DYLIB,        # Dynamically bound shared library
      0x00000007 => :MH_DYLINKER,     # Dynamic link editor (dyld itself)
      0x00000008 => :MH_BUNDLE,       # Dynamically bound object‐code bundle
      0x00000009 => :MH_DYLIB_STUB,   # Shared library stub – static linking only (sections have no content)
      0x0000000a => :MH_DSYM,         # “companion file with only debug sections”
      0x0000000b => :MH_KEXT_BUNDLE,  # X86_64 kernel extension
      0x0000000c => :MH_FILESET       # “set of Mach‐Os”
    }.freeze
  MAX_N_FAT = 30.freeze  # 3 times Apple’s historical limit

  # Mach-O binary methods.  See <mach-o/loader.h> and <mach-o/fat.h>.
  # @private
  def mach_data
    @mach_data ||= \
      begin
        offsets = []
        data = []
        sig, rvsd, n_fat = machO_sig_at?(0)
        if (@fat_container = (sig == :FAT_MAGIC))
          # Each `struct fat_arch` takes up five uint32 (net 20 octets).  `offset` is the third of them (eight octets in, & further
          # offset by the eight octets of the initial `struct fat_header`).
          n_fat.times{ |i| offsets << binread(4, 16 + 20*i).unpack(rvsd ? 'V' : 'N').first } unless size < n_fat * 20 + 8
        elsif sig == :MH_MAGIC then offsets << 0; end  # Thin binary (single bare slice).
        offsets.each do |offset|
          break if size < (offset + 28)  # Of the seven uint32 in a Mach-O file header, only the second and fourth (at offset + 4 &
                                         # offset + 12, respectively) matter here.  One holds the CPU type & flags; the other holds
                                         # the Mach file type.
          sig, rvsd, cpu_type = machO_sig_at?(offset)
          next unless sig == :MH_MAGIC and arch = case cpu_type
                                                    when 0x00000007 then :i386
                                                    when 0x00000012 then :ppc
                                                    when 0x01000007 then :x86_64
                                                    when 0x0100000c then :arm64
                                                    when 0x01000012 then :ppc64
                                                  end
          data << { :arch => arch, :ftype => MACH_FILE_TYPE[binread(4, offset + 12).unpack(rvsd ? 'V' : 'N').first] }
        end # each offset
        data.uniq
      rescue  # from error during @mach_data construction
        []
      end # @mach_data construction
  end # mach_data

  def archs
    @archs ||= mach_data.map{ |m| m[:arch] }.uniq.extend(ALE)
  end

  def arch
    @arch ||= case archs.length
                when 0 then :dunno
                when 1 then archs.first
                else :fat
              end
  end # arch

  def fat_container?; m = mach_data; @fat_container; end  # Generate @mach_data to ensure @fat_container is set correctly.
  def fat?; archs.fat?; end
  def powerpc?; archs.powerpc?; end
  def intel?; archs.intel?; end
  def arm?; archs.arm?; end

  # @private
  def dylib?; mach_data.any?{ |m| m.fetch(:ftype) == :MH_DYLIB }; end

  # @private
  def mach_o_executable?; mach_data.any?{ |m| m.fetch(:ftype) == :MH_EXECUTE }; end

  # @private
  def mach_o_bundle?; mach_data.any?{ |m| m.fetch(:ftype) == :MH_BUNDLE }; end

  def tracked_mach_o?
    mach_data.any?{ |m| ft = m.fetch(:ftype); ft and [:MH_EXECUTE, :MH_DYLIB, :MH_BUNDLE].include?(ft) }
  end

  # Tests data at the indicated offset for a Mach-O or fat‐container signature.  Returns a 3‐tuple giving the signature (if one was
  # found), whether it was stored byte‐reversed (many older files, or slices thereof, are stored in this incorrect manner), and the
  # second uint32 at that location (the number of slices if it was a fat container, or the CPU type if it was a Mach-O slice).  The
  # universal‐binary file signature is the same as a Java file’s, so we must do extra sanity‐checking for that case.  If the number
  # of architectures is large, it is probably not real; Java files, for example, will yield a figure well over 60 thousand.  Assume
  # a limit of MAX_N_FAT architectures; at present, we only expect members of the set {:ppc, :i386, :ppc64, :x86_64, :arm64}.
  def machO_sig_at?(offset)
    sig, _2nd = binread(8, offset).unpack('NN') if file? and size >= (offset + 8)
    case FILE_SIGNATURES[sig]
      when :FAT_MAGIC              then                        (_2nd <= MAX_N_FAT) ? [:FAT_MAGIC, false, _2nd] : [nil, nil, nil]
      when :FAT_CIGAM              then _2nd = _2nd.byteswap4; (_2nd <= MAX_N_FAT) ? [:FAT_MAGIC, true,  _2nd] : [nil, nil, nil]
      when :MH_CIGAM, :MH_CIGAM_64 then _2nd = _2nd.byteswap4;                       [:MH_MAGIC,  true,  _2nd]
      when :MH_MAGIC, :MH_MAGIC_64 then                                              [:MH_MAGIC,  false, _2nd]
                                   else                                              [ nil,       nil,    nil]
    end
  end # machO_sig_at?()

  # @private
  class Metadata
    OTOOL_RX = /\t(.*) \(compatibility version (?:\d+\.)*\d+, current version (?:\d+\.)*\d+\)/

    attr_reader :path, :dylib_id, :dylibs

    def initialize(path)
      @path = path
      @dylib_id, @dylibs = parse_otool_L_output
    end

    def parse_otool_L_output
      ENV['HOMEBREW_MACH_O_FILE'] = path.expand_path.to_s
      libs = `#{MacOS.otool} -L "$HOMEBREW_MACH_O_FILE"`.split("\n")
      unless $?.success?
        raise ErrorDuringExecution.new(MacOS.otool,
          ['-L', ENV['HOMEBREW_MACH_O_FILE']])
      end
      libs.shift # first line is the filename
      id = libs.shift[OTOOL_RX, 1] if path.dylib?
      libs.map! { |lib| lib[OTOOL_RX, 1] }.compact!

      return id, libs
    ensure
      ENV.delete 'HOMEBREW_MACH_O_FILE'
    end # parse_otool_L_output
  end # Mach::Metadata

  # @private
  def mach_metadata; @mach_metadata ||= Metadata.new(self); end

  # Returns an array containing all dynamically-linked libraries, based on the output of otool.  This returns the install names, so
  # these are not guaranteed to be absolute paths.  Returns an empty array both for software that links against no libraries, & for
  # non-Mach objects.
  # @private
  def dynamically_linked_libraries; mach_metadata.dylibs; end

  # @private
  def dylib_id; mach_metadata.dylib_id; end
end # MachO
