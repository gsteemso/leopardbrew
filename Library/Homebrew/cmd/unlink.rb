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
        f = Formula.from_installed_prefix(keg)
        if f.uninsinuate_defined?
          if mode.dry_run
            puts "Would uninsinuate #{f.name}"
          else
            puts "Uninsinuating #{f.name}"
            f.uninsinuate
          end
        end
        print "Unlinking #{keg}... "
        puts "#{keg.unlink(mode)} directories and/or symlinks removed"
      end
    end
  end
end
