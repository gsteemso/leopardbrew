#:
#:  Usage:  brew list-archs [--thorough] /installed formula/ [...]
#:
#:List what hardware architectures each given /installed formula/ was brewed for.
#:The data available from the brewing system are somewhat uneven, so executables
#:built for some CPU architectures are more accurately labelled than those built
#:for others.
#:
#:The /--thorough/ flag elicits a more detailed breakdown of the types of binary
#:program built for each /installed formula/.
#:
#:The results are shown after a short, but non‐trivial delay.  (Certain formulae
#:do weird things which require every last file within each keg to be examined.)
#:

CPU_TYPES = {
  '00000001' => 'VAX',
  '00000002' => 'ROMP',
  '00000004' => 'NS32032',
  '00000005' => 'NS32332',
  '00000006' => 'M68k',
  '01000006' => 'A68k',
  '00000007' => 'i386',
  '01000007' => 'x86-64',
  '00000008' => 'MIPS',
  '01000008' => 'MIPS64',
  '00000009' => 'NS32532',
  '0000000a' => 'M98k',
  '0000000b' => 'PA',
  '0100000b' => 'PA64',
  '0000000c' => 'ARM',
  '0100000c' => 'ARM64',
  '0200000c' => 'ARM64/32',
  '0000000d' => 'M88k',
  '0000000e' => 'SPARC',
  '0100000e' => 'SPARC64',
  '0000000f' => 'i860',
  '01000010' => 'Alpha',
  '00000011' => 'RS6000',
  '00000012' => 'PPC',
  '01000012' => 'PPC64',
  '000000ff' => 'VEO',
}.freeze

PPC_SUBTYPES = {
  '00000000' => 'ppc‐*',
  '00000001' => 'ppc601',
  '00000002' => 'ppc602',
  '00000003' => 'ppc603',
  '00000004' => 'ppc603e',
  '00000005' => 'ppc603ev',
  '00000006' => 'ppc604',
  '00000007' => 'ppc604e',
  '00000008' => 'ppc620',
  '00000009' => 'ppc750',
  '0000000a' => 'ppc7400',
  '0000000b' => 'ppc7450',
  '00000064' => 'ppc970'
}.freeze

module TerminalANSI # standard terminal display-control sequences (yes, can be a wrong assumption)
  # - In the 7‐bit environment UTF‐8 imposes, the Control Sequence Introducer (ᴄꜱɪ) is “ᴇꜱᴄ ‘[’”.
  def csi ; "\033[" ; end
  # - Control sequences containing multiple parameters separate them by ‘;’.
  # - The Select Graphic Rendition (ꜱɢʀ) sequence is “ᴄꜱɪ ⟨Pₛ⟩ ... ‘m’”.
  def sgr(*list) ; "#{csi}#{list.join(';')}m" ; end
  # - The ꜱɢʀ selector‐parameters are:
  def rst    ;   '0' ; end # cancels everything.
  def boldr  ;   '1' ; end # } in theory, these two stack and unstack with each other, but most
  def fntr   ;   '2' ; end # } terminal emulators don’t support 2.
             #    3 was for Italic face, and cancelled 20.
  def undr   ;   '4' ; end # cancels 21.
             #    5–6 were for slow vs. fast blink; don’t care whether they work, flashing is vile.
  def rvs    ;   '7' ; end # inverse video; cancels 27.
  def hidn   ;   '8' ; end # no display; cancels 28.
  def strk   ;   '9' ; end # strikethrough (“shown as deleted”).
             #   10–19 selected the default font 0, or alternate fonts 1–9.
             #   20 was for Gothic face, and cancelled 3.
  def d_undr ;  '21' ; end # cancels 4; probably unsupported by Terminal.app on Tiger or Leopard.
  def reg_wt ;  '22' ; end # cancels 1–2; probably unsupported by Terminal.app on Tiger or Leopard.
             #   23 was for returning to Roman face (cancelled 3 & 20).
  def noundr ;  '24' ; end # cancels 4 & 21.
             #   25 cancelled blinking (5–6).
             #   26 was reserved for proportional‐width characters.
  def no_rvs ;  '27' ; end # cancels 7.
  def nohidn ;  '28' ; end # cancels 8.
  def nostrk ;  '29' ; end # cancels 9.
  def blk    ;  '30' ; end # }
  def red    ;  '31' ; end # }
  def grn    ;  '32' ; end # }
  def ylw    ;  '33' ; end # } "display" (foreground) colours.
  def blu    ;  '34' ; end # }
  def mag    ;  '35' ; end # }
  def cyn    ;  '36' ; end # }
  def wht    ;  '37' ; end # }
             #   38:  Higher‐bit‐depth foreground‐colour extensions.  Unsupported on Tiger/Leopard.
  def dflt   ;  '39' ; end # default display (foreground) colour.
  def on_blk ;  '40' ; end # }
  def on_red ;  '41' ; end # }
  def on_grn ;  '42' ; end # }
  def on_ylw ;  '43' ; end # } background colours.
  def on_blu ;  '44' ; end # }
  def on_mag ;  '45' ; end # }
  def on_cyn ;  '46' ; end # }
  def on_wht ;  '47' ; end # }
             #   48:  Higher‐bit‐depth background‐colour extensions.  Unsupported on Tiger/Leopard.
  def ondflt ;  '49' ; end # default background colour.
             #   50 was reserved to cancel 26.
             #   51–53:  “Framed”, “circled”, & “overlined”.  54 cancelled 51–52; 55 cancelled 53.
             #   56–59 were unused.
             #   60–64 were for ideographs:  Under/right‐line; doubly so; over/left‐line; doubly so;
             #         stress mark.  65 cancelled them; 66–89 were unused.
  def br_blk ;  '90' ; end # }
  def br_red ;  '91' ; end # }
  def br_grn ;  '92' ; end # }
  def br_ylw ;  '93' ; end # } “Display” (foreground) colours.  Undifferentiated in Tiger’s
  def br_blu ;  '94' ; end # }                                  Terminal.app; brighter in Leopard’s
  def br_mag ;  '95' ; end # }                                  et seq.
  def br_cyn ;  '96' ; end # }
  def br_wht ;  '97' ; end # } ___
  def onbblk ; '100' ; end # }
  def onbred ; '101' ; end # }
  def onbgrn ; '102' ; end # }
  def onbylw ; '103' ; end # } Background colours.  Undifferentiated in Tiger’s Terminal.app;
  def onbblu ; '104' ; end # }                      brighter in Leopard’s et seq.
  def onbmag ; '105' ; end # }
  def onbcyn ; '106' ; end # }
  def onbwht ; '107' ; end # }

  # - ꜱɢʀ is affected by the Graphic Rendition Combination Mode (ɢʀᴄᴍ).  The default (off) ɢʀᴄᴍ
  #   state, REPLACING, causes any ꜱɢʀ sequence to reset all parameters it doesn’t explicitly
  #   mention; enabling the CUMULATIVE state allows effects to persist until cancelled.  Luckily,
  #   OS X’s Terminal app seems to ignore the standard and default this to the more sensible
  #   CUMULATIVE state, at least under Leopard.
  # - If ɢʀᴄᴍ is in the REPLACING state and needs to be set CUMULATIVE, the Set Mode (ꜱᴍ) sequence
  #   is “ᴄꜱɪ ⟨Pₛ⟩ ... ‘h’” and the parameter value for ɢʀᴄᴍ is 21.  Should it for some reason need
  #   to be changed back to REPLACING, the Reset Mode (ʀᴍ) sequence is “ᴄꜱɪ ⟨Pₛ⟩ ... ‘l’”.
  def set_grcm_cumulative ; "#{csi}21h" ; end
  def set_grcm_replacing  ; "#{csi}21l" ; end

  def bolder_on_black ; sgr(boldr, on_blk) ; end
  def in_yellow(msg) ; sgr(ylw) + msg.to_s + sgr(dflt) ; end
  def in_cyan(msg) ; sgr(cyn) + msg.to_s + sgr(dflt) ; end
  def in_white(msg) ; sgr(wht) + msg.to_s + sgr(dflt) ; end
  def in_br_red(msg) ; sgr(br_red) + msg.to_s + sgr(dflt) ; end
  def in_br_yellow(msg) ; sgr(br_ylw) + msg.to_s + sgr(dflt) ; end
  def in_br_blue(msg) ; sgr(br_blu) + msg.to_s + sgr(dflt) ; end
  def in_br_cyan(msg) ; sgr(br_cyn) + msg.to_s + sgr(dflt) ; end
  def in_br_white(msg) ; sgr(br_wht) + msg.to_s + sgr(dflt) ; end
  def resetgr ; sgr(rst) ; end
end # TerminalANSI

module Homebrew
  extend TerminalANSI
  set_grcm_cumulative

  def oho(*msg); puts "#{bolder_on_black}#{in_br_blue '==>'} #{msg.to_a * ''}#{resetgr}"; end

  def ohey(title, *msg); oho title; puts msg; end

  def list_archs
    thorough_flag = ARGV.include? '--thorough'
    requested = (thorough_flag ? ARGV.installed_kegs : ARGV.kegs)
    raise KegUnspecifiedError if requested.empty?
    no_archs_msg = false; got_generic_ppc = false

    def scour(loc)
      possibles = []
      Dir["#{loc}/{*,.*}"].reject{ |f| f =~ %r{/\.\.?$} }.map{ |f| Pathname.new(f) }.each do |pn|
        unless pn.symlink?
          if pn.directory? then possibles += scour(pn)
          elsif pn.mach_o_signature_at?(0) or pn.ar_signature_at?(0) then possibles << pn
          end
        end # unless symlink?
      end # each |pn|
      possibles
    end # scour

    def cpu_valid(type, subtype)
      case CPU_TYPES[type]
        when /^ARM/, 'i386', 'x86-64' then CPU_TYPES[type]
        when 'PPC'
          got_generic_ppc = (val = PPC_SUBTYPES[subtype] and val == 'ppc‐*')
          val
        when 'PPC64' then 'ppc64'
        else nil
      end
    end # cpu_valid

    def report_1_arch_at(pname, offset)
      # Generate a key from a one‐architecture (sub‐)file:
      return [nil, nil] unless pname.size > offset + 12
      cpu_type, cpu_subtype = pname.binread(8, offset + 4).unpack('H8H8')
      if arch = cpu_valid(cpu_type, cpu_subtype) then key = [in_br_cyan(arch)]; alien_report = nil
      else # alien arch
        ct = (CPU_TYPES[cpu_type] or cpu_type)
        key = [in_cyan("#{ct}:#{cpu_subtype}")]
        alien_report = \
          "File #{in_white(pname)}:\n  [foreign CPU type #{in_cyan(ct)} with subtype #{in_cyan(cpu_subtype)}].\n"
      end # native arch?
      return [key, alien_report]
    end

    requested.each do |keg|
      max_arch_count = 0; arch_reports = {}; alien_reports = []
      scour(keg.to_s).each do |pn|
        if offset = pn.ar_sigseek_from(0) # ‘ar’ archive:  Only look until the first Mach-O signature.
          key, alien_report = report_1_arch_at(pn, offset)
          alien_reports << alien_report if alien_report
        elsif sig = pn.mach_o_signature_at?(0)
          if sig == :FAT_MAGIC  # only returns this if we have 7 or fewer fat_archs
            if (arch_count = pn.fat_count_at(0)) > 0
              # Generate a key describing this set of architectures.  First, extract the list of them:
              parts = []
              arch_count.times{ |i| parts << pn.binread(8, 8 + 20*i).unpack('H8H8') }
              native_parts = []
              foreign_parts = []
              parts.each do |part|
                cpu_type, cpu_subtype = part
                if arch = cpu_valid(cpu_type, cpu_subtype)
                  native_parts << in_br_cyan(arch)
                else
                  ct = (CPU_TYPES[cpu_type] or cpu_type)
                  foreign_parts << {
                      { :type => ct, :subtype => cpu_subtype } =>
                        "[foreign CPU type #{in_cyan(ct)} with subtype #{in_cyan(cpu_subtype)}.]"
                    }
                end # valid arch?
              end # do each |part|
              # Second, sort the list:
              native_parts.sort! do |a, b|
                # the ꜱɢʀ sequences at beginning and end are 5 characters each
                if a[5..7] == 'ppc' and b[5..7] == 'ppc' # sort ppc64 after all other ppc types
                  if a[8..-6] == '64' then b[8..-6] == '64' ? 0 : 1
                  elsif b[8..-6] == '64' then -1
                  else a <=> b; end  # sort other ppc types
                else a <=> b; end  # sort all other types
              end if native_parts.length > 1
              foreign_parts.sort! do |a, b|
                if a.keys.first[:type] < b.keys.first[:type] then -1
                elsif a.keys.first[:type] > b.keys.first[:type] then 1
                else a.keys.first[:subtype] <=> b.keys.first[:subtype]; end
              end if foreign_parts.length > 1
              # Third, use the sorted list as a search key:
              key = native_parts + foreign_parts.map{ |fp|
                  "#{in_cyan(fp.keys.first[:type])}:#{in_cyan(fp.keys.first[:subtype])}"
                }
              alien_reports << "File #{in_white(pn)}:\n  #{foreign_parts.map{ |fp| fp.values.first } * "\n  "}\n" \
                                                                             if foreign_parts != []
            end # (arch_count > 0)?
          elsif sig # :MH_MAGIC, :MH_MAGIC_64
            key, alien_report = report_1_arch_at(pn, 0)
            alien_reports << alien_report if alien_report
          end # Fat / Mach-O sig?
        end # ‘ar’ or Mach-O?
        if key
          if arch_reports[key] then arch_reports[key] += 1
          else arch_reports[key] = 1; end
        end
      end # do each |pn|
      if arch_reports == {}
        oho "#{in_white(keg.name)} appears to contain #{in_yellow('no valid Mach-O files')}."
        no_archs_msg = true
      else # there are arch reports
        machO_count = arch_reports.values.sum
        ohey("#{in_white(keg.name)} appears to contain some foreign code:", alien_reports * '') \
                                                                             if alien_reports != []
        unless thorough_flag
          combo_incidence = arch_reports.values.max  # How often did the most common arch combos occur?
          arch_reports.select!{ |k, v| v == combo_incidence }  # Only report those most‐common combos
          if arch_reports.length > 1
            arch_count = arch_reports.keys.map{ |k| k.length }.max  # How many archs appear in the most complex combos?
            arch_reports.select!{ |k, v| k.length == arch_count }  # only report those most‐complex combos
          end # more than one arch report?
          arch_reports.reject!{ |r| r.any?{ |rr| rr =~ /ppc‐\*/ } } if arch_reports.length > 1
        end # not thorough?
        oho "#{in_white("#{keg.name} #{keg.path.basename}")} is built#{thorough_flag ? '' : ' primarily'} for ",
          "#{in_br_white(arch_reports.length)} combination#{plural(arch_reports.length)} of architectures:  ",
          arch_reports.keys.sort{ |a, b|        # descending by incidence, then by complexity
              (c = arch_reports[b] <=> arch_reports[a]) == 0 ? (b.length <=> a.length) : c
            }.map{
              |k| "#{k * in_white('/')} (#{'×' + arch_reports[k].to_s})"
            } * ', ', " (#{machO_count} Mach-O binaries in total)."
      end # any archs found?
    end # do each |keg|
    if no_archs_msg
      puts <<-_.undent
        Sometimes a successful brew produces no Mach-O binary files.  This can happen
        if, for example, the formula responsible installs only header, documentation,
        or script files.
      _
    end # no_archs_msg?
  end # list_archs
end # Homebrew

class Array; def sum; total = 0; each{ |e| total += e.to_i }; total; end; end
