#:
#:Unlink, switch out, and relink your Homebrew (Leopardbrew) Cellar.
#:
#:  Usage:
#:
#:    brew switch-cellar --save-as=/stash name/ [ --use-new=/prior cellar/ ]
#:
#:    brew switch-cellar --refresh
#:
#:In the first form, disconnect everything from the currently active Cellar, then
#:rename it to “/stash name/-Cellar”.  After the thitherto‐active Cellar has been
#:stashed away, rename “/prior cellar/-Cellar” to become the active Cellar.  Each
#:expected linkage to it is then restored.  If no replacement Cellar is supplied,
#:an empty one is created.
#:
#:In the second form, disconnect and then immediately reconnect everything within
#:the current Cellar.  This repairs any and all incorrect or damaged linkages.
#:
#:Both forms should correctly handle pinned formulæ.
#:

require 'formula'
require 'formula_pin'
require 'formulary'
require 'keg'
require 'ostruct'
require 'tab'

module Homebrew
  def switch_cellar
    def sever_racklist(rack_list, mode)
      done_list = []
      rack_list.each do |rack|
        kegs = rack.subdirs.map { |subdir| Keg.new(subdir) }
        kegs.each do |keg|
          begin 
            keg.unlink(mode) if keg.linked?
            keg.remove_opt_record unless mode.dry_run
            done_list << rack
          rescue FormulaUnavailableError
            unsever_racklist(done_list, mode)
            raise RuntimeError "Can’t unlink #{keg.name}:  No formula.  Aborting"
          rescue
            # silently ignore all other errors
          end
        end # each |keg|
      end # each |rack|
      LINKDIR.rmtree if (LINKDIR.exist? and not mode.dry_run)
    end # sever_racklist

    def unsever_racklist(rack_list, mode)
      rack_list.each do |rack|
        pin_candidate = PINDIR/rack.basename
        if (pin_candidate.exist? and pin_candidate.symlink? and pin_candidate.directory?)
          keg = Keg.new(pin_candidate.realpath)  # meant to pick up the target, not the symlink
        else
          keg = Keg.new(rack.subdirs.sort.last)  # link the latest version
        end
        begin
          keg.optlink(mode)
          keg.link(mode) unless Formulary.from_rack(rack).keg_only?
        rescue FormulaUnavailableError
          puts "Couldn’t re‐link #{keg.name}:  No formula.  Skipping it"
        rescue AlreadyLinkedError
          begin
            keg.remove_linked_keg_record
            redo
          rescue
            # silently ignore all further errors
          end
        rescue
          # silently ignore all other errors
        end
      end # each |rack|
    end # unsever_racklist

    def annulnil(arg); (arg.nil? ? '' : arg); end

    raise RuntimeError 'You have no Cellar to switch' unless HOMEBREW_CELLAR.directory?
    HOMEBREW_CELLAR.parent.cd do
      mode = OpenStruct.new
      mode.dry_run = ARGV.dry_run?
      if ARGV.include? '--refresh'  # regenerating links in place
        sever_racklist(HOMEBREW_CELLAR.subdirs, mode)
        unsever_racklist(HOMEBREW_CELLAR.subdirs, mode)
      else  # swapping Cellars wholesale
        # pathnames – either absolute, or relative to the current (Cellar’s parent) directory:
        save_as = Pathname(annulnil ARGV.value('save-as'))
        raise UsageError 'The “--save-as=_____” flag must give a name' if save_as == ''
        use_new = Pathname(annulnil ARGV.value('use-new'))
        # use_new == '' is an expected use case, so no error for that
        got_pins = PINDIR.exist?
        cellar_stash = Pathname("#{save_as.to_s}-Cellar")
        cellar_stash.dirname.mkdir_p unless cellar_stash.dirname.exist?
        cellar_stash = cellar_stash.realdirpath
        raise RuntimeError "#{cellar_stash}:  This entity already exists" if cellar_stash.exist?
        if got_pins
          pin_stash = Pathname("#{save_as.dirname}/Library/#{save_as.basename}-PinnedKegs")
          pin_stash.dirname.mkdir_p unless pin_stash.dirname.exist?
          pin_stash = pin_stash.realdirpath
          raise RuntimeError "#{pin_stash}:  This entity already exists" if pin_stash.exist?
        end
        sever_racklist(HOMEBREW_CELLAR.subdirs, mode)
        if mode.dry_run?
          puts "Would rename #{HOMEBREW_CELLAR} to #{cellar_stash}"
          puts "Would rename #{PINDIR} to #{pin_stash}" if got_pins
        else
          begin
            HOMEBREW_CELLAR.rename cellar_stash
          rescue
            unsever_racklist(HOMEBREW_CELLAR.subdirs, mode)
            raise RuntimeError 'Couldn’t rename the old Cellar'
          end
          if got_pins
            begin
              PINDIR.rename pin_stash
            rescue
              cellar_stash.rename HOMEBREW_CELLAR
              unsever_racklist(HOMEBREW_CELLAR.subdirs, mode)
              raise RuntimeError "Couldn’t rename #{PINDIR}"
            end
          end
        end
        if use_new != ''
          new_cellar = Pathname("#{use_new}-Cellar")
          unless new_cellar.exist?
            # Create an empty Cellar as a placeholder, because if we don’t, future invocations of
            # Homebrew will switch to the default location regardless of where the current one is.
            HOMEBREW_CELLAR.mkdir unless mode.dry_run
            raise RuntimeError "#{new_cellar}:  The specified replacement Cellar does not exist"
          end
          new_pin = Pathname("#{use_new.dirname}/Library/#{use_new.basename}-PinnedKegs")
          got_pins = new_pin.exist?
          if mode.dry_run
            puts "Would rename #{new_cellar} to #{HOMEBREW_CELLAR}"
            new_cellar.subdirs.each do |rack|
              begin
                f = Formulary.from_rack(rack)
              rescue FormulaUnavailableError
                puts "Would be unable to proceed due to lacking a formula for #{rack.basename}"
              rescue
                # silently ignore all other errors
              end
              if f.keg_only?
                puts "Would not link #{rack.basename} because it is keg‐only"
              else
                pin_candidate = new_pin/rack.basename
                if (got_pins and pin_candidate.symlink?)
                  specific_version = pin_candidate.readlink.basename
                else
                  specific_version = rack.subdirs.sort.last.basename
                end
                puts "Would link #{rack.basename} version #{specific_version}"
              end # keg‐only?
            end # each rack
          else # not a dry run
            begin
              new_cellar.rename HOMEBREW_CELLAR
            rescue
              raise RuntimeError "Couldn’t rename #{new_cellar}"
            end
            unsever_racklist(HOMEBREW_CELLAR.subdirs, mode)
          end # dry run?
        else # use_new == ''
          if mode.dry_run
            puts 'Would create a new, empty Cellar'
          else
            HOMEBREW_CELLAR.mkdir  # create an empty Cellar, as specified
          end
        end # new cellar
      end # swapping Cellars, not regenerating links in place
    end # cd into HOMEBREW_CELLAR.parent
  end # switch_cellar
end # module Homebrew
