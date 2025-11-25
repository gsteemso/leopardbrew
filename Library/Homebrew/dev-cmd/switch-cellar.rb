#:Unlink, switch out, and relink your Homebrew (Leopardbrew) Cellar.
#:
#:  Usage:
#:
#:    brew switch-cellar [-n] --save-as=/stash_name/ [--use-new=/prior_cellar/]
#:
#:    brew switch-cellar --refresh
#:
#:In the first form, disconnect everything from the currently active Cellar, then
#:rename it to “/stash name/-Cellar”.  After the thitherto‐active Cellar has been
#:stashed away, rename “/prior cellar/-Cellar” to become the active Cellar.  Each
#:expected linkage to it is then restored.  If no replacement Cellar is supplied,
#:an empty one is created.  “-n” is the standard “--dry-run” switch, either form.
#:
#:In the second form, disconnect and then immediately reconnect everything within
#:the current Cellar.  This repairs any and all incorrect or damaged linkages.
#:
#:Both forms should correctly handle pinned formulæ.

require 'formula'
require 'formula/pin'
require 'formulary'
require 'keg'
require 'ostruct'
require 'tab'

module Homebrew
  def switch_cellar
    def get_linked_keg(name)
      link = LINKDIR/name
      Keg.for(link.resolved_path) rescue nil if link.exists? and link.directory? and link.symlink?
    end

    def sever_racklist(_cellar, mode)
      seen_bash = false
      switched_list = HOMEBREW_CELLAR/'SwitchedList'
      switched_list.truncate(0) unless mode.dry_run
      _cellar.subdirs.each do |rack|
        if (rack/'.DS_Store').exists? then rm rack/'.DS_Store'; end
        kegs = rack.subdirs.sort.reverse.map{ |k| Keg.new(k) }
        if kegs.empty? then rack.rmdir_if_possible; next; end
        (keg = kegs.find{ |k| k.optlinked? } || get_linked_keg(rack.basename) || kegs.first).lock do
          begin
            f = Formulary.from_keg(keg)
            switched_list.append "#{keg.versioned_name.sub(/=/, "\t")}\n" unless mode.dry_run
            if keg.name == 'bash' then seen_bash = keg
            else
              if f and f.insinuation_defined?
                if mode.dry_run then puts "Would uninsinuate #{f.name}"
                else f.uninsinuate rescue nil; end
              end
              keg.unlink(mode)
              keg.remove_opt_record unless mode.dry_run
            end
          rescue Exception => e
            puts "#{e.class}:  #{e.message}", e.backtrace
            # silently ignore all other errors
          end
        end # lock
      end # each |rack|
      if seen_bash
        if mode.dry_run then puts "Would uninsinuate bash"
        else Formula['bash'].uninsinuate rescue nil; end
        seen_bash.unlink(mode)
        seen_bash.remove_opt_record unless mode.dry_run
      end
      LINKDIR.rmtree if (LINKDIR.exists? and not mode.dry_run)
    end # sever_racklist

    def read_switched_hash(_cellar)
      hsh = {}
      File.open(_cellar/'SwitchedList', O_RDONLY) do |f|
        while line = f.gets do hsh[line[/^[^\t]+/]] = line[/[^\t]+$/].chomp; end
      end rescue nil
      hsh
    end # read_switch_hash

    def synthesize_switched_hash
      hsh = {}
      HOMEBREW_CELLAR.subdirs.each do |rack|
        if (rack/'.DS_Store').exists? then rm rack/'.DS_Store'; end
        kegs = rack.subdirs.sort.reverse.map{ |k| Keg.new(k) }
        if kegs.empty? then rack.rmdir_if_possible; next; end
        keg = kegs.find{ |k| k.optlinked? } || get_linked_keg(rack.basename) || kegs.first
        hsh[keg.name] = keg.versioned_name[/[^=]+$/]
      end
      hsh
    end

    def unsever_racklist(_cellar, mode)
      seen_bash = false
      switched_hash = mode.dry_run ? synthesize_switched_hash : read_switched_hash(_cellar)
      _cellar.subdirs.each do |rack|
        if (rack/'.DS_Store').exists? then rm rack/'.DS_Store'; end
        pin_candidate = PINDIR/rack.basename; keg = nil
        if (pin_candidate.exists? and pin_candidate.symlink? and pin_candidate.directory?)
          keg = Keg.new(pin_candidate.realpath, _cellar)   # Meant to pick up the target, not the symlink.
        else
          kegs = rack.subdirs.sort.reverse
          if kegs.empty? then rack.rmdir_if_possible; next; end
          switched_to_version = switched_hash[rack.basename.to_s]
          keg = (switched_to_version ? kegs.find{ |k| k.basename.to_s == switched_to_version } : kegs.first)
          if keg then keg = Keg.new(keg, _cellar); else next; end
        end # (not) pin candidate?
        keg.lock do
          begin
            keg.optlink(mode)
            f = Formulary.from_keg(keg)
            if keg.name == 'bash' then seen_bash = true
            elsif f and f.insinuation_defined?
              if mode.dry_run then puts "Would insinuate #{f.name}"
              else f.insinuate rescue nil; end
            end
            keg.link(mode) unless f and f.keg_only?
          rescue Keg::AlreadyLinkedError
            begin
              keg.remove_linked_keg_record
              redo
            rescue Exception => e
              puts "#{e.class}:  #{e.message}", e.backtrace
              # silently ignore all further errors
            end
          rescue Exception => e
            puts "#{e.class}:  #{e.message}", e.backtrace
            # silently ignore all other errors
          end
        end # lock
      end # each |rack|
      if seen_bash
        if mode.dry_run then puts "Would insinuate bash"
        else Formula['bash'].insinuate rescue nil; end
      end
      (_cellar/'SwitchedList').unlink unless mode.dry_run
    end # unsever_racklist

    raise RuntimeError, 'You have no Cellar to switch' unless HOMEBREW_CELLAR.directory?
    HOMEBREW_CELLAR.parent.cd do
      mode = OpenStruct.new
      mode.dry_run = ARGV.dry_run?
      if ARGV.include? '--refresh'  # regenerating links in place
        sever_racklist(HOMEBREW_CELLAR, mode)
        unsever_racklist(HOMEBREW_CELLAR, mode)
      else  # swapping Cellars wholesale
        # pathnames – either absolute, or relative to the current (Cellar’s parent) directory:
        unless (save_as = ARGV.value('save-as').choke)
          raise RuntimeError, 'A name must be supplied with the “--save-as” flag'; end
        use_new = ARGV.value('use-new').choke
          # use_new being undefined is an expected use case, so no error for that
        got_pins = PINDIR.exists?
        cellar_stash = Pathname("#{save_as}-Cellar").realdirpath
        pin_stash = cellar_stash/'PinnedKegs'
        raise FileExistsError, cellar_stash if cellar_stash.exists?
        sever_racklist(HOMEBREW_CELLAR, mode)
        if mode.dry_run
          puts "Would move #{HOMEBREW_CELLAR} to #{cellar_stash}"
          puts "Would move #{PINDIR} to #{pin_stash}" if got_pins
        else
          problem = :none
          begin
            problem = :cellar
            HOMEBREW_CELLAR.rename cellar_stash
            if got_pins
              problem = :pindir
              pin_stash.rmtree if pin_stash.exists?
              PINDIR.rename pin_stash
            end
          rescue
            cellar_stash.rename HOMEBREW_CELLAR if cellar_stash.exists?
            (HOMEBREW_CELLAR/'PinnedKegs').rename PINDIR if (HOMEBREW_CELLAR/'PinnedKegs').exists?
            unsever_racklist(HOMEBREW_CELLAR, mode)
            raise RuntimeError, case problem
                                  when :cellar  then 'Couldn’t move the old Cellar'
                                  when :pindir  then "Couldn’t move #{PINDIR}"
                                end
          end
        end # dry run?
        if use_new
          new_cellar = Pathname("#{use_new}-Cellar").realpath rescue nil
          unless new_cellar and new_cellar.exists?
            # Create an empty Cellar as a placeholder, because if we don’t, future invocations of
            # Homebrew will switch to the default location regardless of where the current one is.
            HOMEBREW_CELLAR.mkdir unless mode.dry_run
            raise RuntimeError, "#{new_cellar}:  The specified replacement Cellar does not exist"
          end
          new_pin = new_cellar/'PinnedKegs'
          got_pins = new_pin.exists?
          cellar_to_unsever = if mode.dry_run
              puts "Would move #{new_cellar} to #{HOMEBREW_CELLAR}"
              puts "Would move #{new_pin} to #{PINDIR}" if got_pins
              new_cellar
            else # not a dry run
              problem = :none
              begin
                problem = :cellar
                new_cellar.rename HOMEBREW_CELLAR
                if got_pins
                  problem = :pindir
                  PINDIR.rmtree if PINDIR.exists?
                  (HOMEBREW_CELLAR/'PinnedKegs').rename PINDIR
                end
              rescue
                HOMEBREW_CELLAR.mkdir unless HOMEBREW_CELLAR.exists?
                raise RuntimeError, case problem
                                      when :cellar  then 'Couldn’t move the new Cellar'
                                      when :pindir  then "Couldn’t move #{new_pin}"
                                    end
              end
              HOMEBREW_CELLAR
            end # dry run?
          unsever_racklist(cellar_to_unsever, mode)
        elsif mode.dry_run then puts 'Would create a new, empty Cellar'
        else HOMEBREW_CELLAR.mkdir; end
      end # swapping Cellars, not regenerating links in place
    end # cd into HOMEBREW_CELLAR.parent
  end # switch_cellar
end # module Homebrew
