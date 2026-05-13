require 'ostruct'

module Homebrew
  def unlink
    raise KegUnspecifiedError if ARGV.named.empty?

    mode = OpenStruct.new
    mode.dry_run = true if ARGV.dry_run?

    ARGV.kegs.each do |keg|
      if mode.dry_run
        puts 'Would remove:'
        keg.unlink(mode)
        next
      end
      keg.lock do
        print "Unlinking #{keg}... "
        puts "#{keg.unlink(mode)} directories and/or symlinks removed"
      end
    end # each ARGV |keg|
  end # unlink
end # Homebrew
