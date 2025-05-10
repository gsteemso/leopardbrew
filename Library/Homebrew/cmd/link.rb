require "ostruct"

module Homebrew
  def link
    raise KegUnspecifiedError if ARGV.named.empty?

    mode = OpenStruct.new
    mode.overwrite = true if ARGV.include? "--overwrite"
    mode.dry_run = true if ARGV.dry_run?

    ARGV.kegs.each do |keg|
      if keg.linked?
        opoo "Already linked: #{keg}"
        puts "To relink: brew unlink #{keg.name} && brew link #{keg.name}"
        next
      end
      f = keg.formula
      if f.keg_only? and not ARGV.force?
        opoo "#{keg.name} is keg-only and must be linked with --force"
        puts "Note that doing so can interfere with building software."
        next
      elsif mode.dry_run
        puts(mode.overwrite ? "Would replace:" : "Would link:") 
        keg.link(mode)
        next
      end
      keg.lock do
        if f.insinuate_defined?
          if mode.dry_run
            puts "Would insinuate #{f.name}"
          else
            puts "Insinuating #{f.name}"
            f.insinuate
          end
        end
        print "Linking #{keg}... "
        begin
          n = keg.link(mode)
        rescue Keg::LinkError
          puts
          raise
        else
          puts "#{n} directories and/or symlinks created"
        end
      end # keg lock
    end # each ARGV |keg|
  end # link
end # Homebrew
