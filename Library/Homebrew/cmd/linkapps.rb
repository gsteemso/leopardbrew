#:  Usage:  brew linkapps [--local] [formula [...]]
#:
#:Links any Mac OS applications (“.app” bundles) it finds in the given installed
#:formulæ to /Applications, or to ~/Applications if “--local” was passed.  If no
#:formulæ are specified on the command line, examines all installed formulæ.
require 'keg'
require 'formula'

module Homebrew
  def linkapps
    target_dir = Pathname(ARGV.includes?('--local') ? File.expand_path('~/Applications') : '/Applications')
    odie("#{target_dir} does not exist, stopping.", "Run `mkdir #{target_dir}` first.") unless target_dir.exists?
    (ARGV.named.empty? ? Formula.racks.map do |rack|
                           keg_list = rack.subdirs.map{ |d| Keg.new(d) }
                           next if keg.empty?
                           keg_list.detect(&:linked?) || keg_list.max{ |a, b| a.version <=> b.version }
                         end \
                       : ARGV.kegs
    ).each do |keg|
      keg = keg.optlinked? ? keg.opt_record.to_s : keg.to_s
      (Dir["#{keg}/*.app"] + Dir["#{keg}/bin/*.app"] + Dir["#{keg}/libexec/*.app"]).each do |app|
        next unless File.directory?(app)  # If it isn’t a real application bundle, linking it will do more harm than good.
        puts "Linking #{app} to #{target_dir}."
        app_name = File.basename(app)
        target = target_dir/app_name
        if target.really_exists? then onoe "#{target} already exists, skipping."; next; end
        system 'ln', '-sf', app, target_dir.to_s
      end # each |app|
    end # each |keg|
  end # Homebrew#linkapps
end # Homebrew
