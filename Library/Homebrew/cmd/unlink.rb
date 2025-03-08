require "ostruct"

module Homebrew
  def unlink
    raise KegUnspecifiedError if ARGV.named.empty?

    mode = OpenStruct.new
    mode.dry_run = true if ARGV.dry_run?

    ARGV.kegs.each do |keg|
      if mode.dry_run
        puts "Would remove:"
        keg.unlink(mode)
        next
      end

      keg.lock do
        print "Unlinking #{keg}... "
        # Do not uninsinuate here, because formulæ using insinuation are normally keg-only and
        # would not expect to be linked in the first place.
        puts "#{keg.unlink(mode)} symlinks removed"
      end
    end
  end
end
