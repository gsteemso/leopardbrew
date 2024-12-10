# On a Mac, this file is loaded before `global.rb`, so must eschew most
# Homebrew‐isms at eval time.

require "os"

class Hardware
  module CPU
    extend self

    def type; :dunno; end

    def arch; :dunno; end

    def model; :dunno; end

    def cores; 1; end

    def bits; 64; end

    def is_32_bit?; bits == 32; end

    def is_64_bit?; bits == 64; end

    def arm?; type == :arm; end

    def intel?; type == :intel; end

    def ppc?; type == :ppc; end

    def features; []; end

    def feature?(name); features.include?(name); end

    def can_run?(this)
      if is_32_bit? then arch_32_bit == this
      else case type
          when :arm   then :arm64 == this
          when :intel then [:i386, :x86_64].include? this
          when :ppc   then [:ppc, :ppc64].include? this
          else false
        end
      end
    end # can_run?
  end # CPU

  if OS.mac?
    require "os/mac/hardware"
    CPU.extend MacCPUs
  elsif OS.linux?
    require "os/linux/hardware"
    CPU.extend LinuxCPUs
  else
    raise "The system `#{`uname`.chomp}' is not supported."
  end

  def self.cores_as_words
    case Hardware::CPU.cores
      when 1 then "single"
      when 2 then "dual"
      when 4 then "quad"
      else Hardware::CPU.cores
    end
  end # ::cores_as_words

  def self.oldest_cpu(arch_type = Hardware::CPU.type)
    case arch_type
      when :intel then :core
      when :ppc   then :g3
      else :dunno
    end
  end # ::oldest_cpu
end # Hardware
