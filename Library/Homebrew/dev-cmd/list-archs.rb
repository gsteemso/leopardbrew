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

SIGNATURES = {
  'cafebabe' => :FAT_MAGIC,
  'feedface' => :MH_MAGIC,
  'feedfacf' => :MH_MAGIC_64,
}.freeze

CPU_TYPES = {
  '00000001' => 'VAX',
  '00000002' => 'ROMP',
  '00000004' => 'ns32032',
  '00000005' => 'ns32332',
  '00000006' => 'm68k',
  '01000006' => 'a68k',
  '00000007' => 'i386',
  '01000007' => 'x86-64',
  '00000008' => 'MIPS',
  '01000008' => 'MIPS64',
  '00000009' => 'ns32532',
  '0000000a' => 'm98k',
  '0000000b' => 'PA',
  '0100000b' => 'PA64',
  '0000000c' => 'ARM',
  '0100000c' => 'ARM64',
  '0200000c' => 'ARM64/32',
  '0000000d' => 'm88k',
  '0000000e' => 'SPARC',
  '0100000e' => 'SPARC64',
  '0000000f' => 'i860',
  '01000010' => 'Alpha',
  '00000011' => 'RS6000',
  '00000012' => 'PPC',
  '01000012' => 'PPC64',
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

module Term_seq # standard terminal display-control sequences (yes, can be a wrong assumption)
  module_function
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
             #   38 is for extensions to higher‐bit‐depth foreground colours; Terminal.app doesn’t
             #      support any of them under Tiger or Leopard.
  def dflt   ;  '39' ; end # default display (foreground) colour.
  def on_blk ;  '40' ; end # }
  def on_red ;  '41' ; end # }
  def on_grn ;  '42' ; end # }
  def on_ylw ;  '43' ; end # } background colours.
  def on_blu ;  '44' ; end # }
  def on_mag ;  '45' ; end # }
  def on_cyn ;  '46' ; end # }
  def on_wht ;  '47' ; end # }
             #   48 is for extensions to higher‐bit‐depth background colours; Terminal.app doesn’t
             #      support any of them under Tiger or Leopard.
  def ondflt ;  '49' ; end # default background colour.
             #   50 was reserved to cancel 26.
             #   51–53 were “framed”, “circled”, & “overlined”.
             #   54 cancelled 51–52 and 55 cancelled 53.
             #   56–59 were unused.
             #   60–64 were for ideographs (underline/right‐line; double of; overline/left‐line;
             #         double of; stress mark); 65 cancelled them.
  # - The following are extensions – Tiger’s Terminal.app treats them the same as their non‐bright
  #   counterparts, but Leopard’s does present them as brighter.
  def br_blk ;  '90' ; end # }
  def br_red ;  '91' ; end # }
  def br_grn ;  '92' ; end # }
  def br_ylw ;  '93' ; end # } “display” (foreground) colours.
  def br_blu ;  '94' ; end # }
  def br_mag ;  '95' ; end # }
  def br_cyn ;  '96' ; end # }
  def br_wht ;  '97' ; end # } ___
  def onbblk ; '100' ; end # }
  def onbred ; '101' ; end # }
  def onbgrn ; '102' ; end # }
  def onbylw ; '103' ; end # } background colours.
  def onbblu ; '104' ; end # }
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
  def self.set_grcm_cumulative ; "#{csi}21h" ; end
  def self.set_grcm_replacing  ; "#{csi}21l" ; end

  def bolder_on_black ; sgr(boldr, on_blk) ; end
  def in_yellow(msg) ; sgr(ylw) + msg.to_s + sgr(dflt) ; end
  def in_cyan(msg) ; sgr(cyn) + msg.to_s + sgr(dflt) ; end
  def in_white(msg) ; sgr(wht) + msg.to_s + sgr(dflt) ; end
  def in_br_red(msg) ; sgr(br_red) + msg.to_s + sgr(dflt) ; end
  def in_br_yellow(msg) ; sgr(br_ylw) + msg.to_s + sgr(dflt) ; end
  def in_br_blue(msg) ; sgr(br_blu) + msg.to_s + sgr(dflt) ; end
  def in_br_cyan(msg) ; sgr(br_cyn) + msg.to_s + sgr(dflt) ; end
  def in_br_white(msg) ; sgr(br_wht) + msg.to_s + sgr(dflt) ; end
  def reset_gr ; sgr(rst) ; end
end # Term_seq

class Pathname
  def mach_o_signature?
    self.file? and
    (self.size >= 28 and SIGNATURES[self.binread(4).unpack('H8').first]) or
    (self.binread(8) == "!<arch>\x0a" and
     self.size >= 72 and
     (self.binread(16, 8) !~ %r|^#1/\d+|   and SIGNATURES[self.binread(4, 68).unpack('H8').first]) or
     (self.binread(16, 8) =~ %r|^#1/(\d+)| and SIGNATURES[self.binread(4, 68+($1.to_i)).unpack('H8').first]))
  end # mach_o_signature
end # Pathname

module Homebrew
  Term_seq.set_grcm_cumulative

  def list_archs
    def oho(*msg)
      puts "#{Term_seq.bolder_on_black}#{Term_seq.in_br_blue '==>'} #{msg.to_a.join('')}#{Term_seq.reset_gr}"
    end

    def ohey(title, *msg)
      oho title
      puts msg
    end

    def scour(in_here)
      possibles = []
      Dir["#{in_here}/{*,.*}"].reject { |f|
        f =~ /\/\.{1,2}$/
      }.map { |m|
        Pathname.new(m)
      }.each do |pn|
        unless pn.symlink?
          if pn.directory?
            possibles += scour(pn)
          elsif pn.mach_o_signature?
            possibles << pn
          end
        end # unless symlink?
      end # each |pn|
      possibles
    end # scour

    def cpu_valid(type, subtype)
      case CPU_TYPES[type]
      when /^ARM/, 'i386', 'x86-64'
        CPU_TYPES[type]
      when 'PPC'
        val = PPC_SUBTYPES[subtype]
        got_generic_ppc = true if val and val == 'ppc‐*'
        val
      when 'PPC64'
        'ppc64'
      else
        nil
      end
    end # cpu_valid

    thorough_flag = ARGV.include? '--thorough'
    requested = (thorough_flag ? ARGV.versioned_kegs : ARGV.kegs)
    raise KegUnspecifiedError if requested.empty?
    no_archs_msg = false
    got_generic_ppc = false
    requested.each do |keg|
      max_arch_count = 0
      arch_reports = {}
      alien_reports = []
      scour(keg.to_s).each do |mo|
        sig = mo.mach_o_signature?
        if sig == :FAT_MAGIC
          arch_count = mo.binread(4,4).unpack('N').first
          # False positives happen, especially with Java files; if the number of architectures is
          #   negative, zero, or implausibly large, it probably isn’t actually a fat binary.
          # Pick an upper limit of 7 in case we ever handle ARM|ARM64|ARM64/32 builds or whatever.
          if (arch_count >= 1 and arch_count <= 7)
        # Generate a key describing this set of architectures.  First, extract the list of them:
            parts = []
            0.upto(arch_count - 1) do |i|
              parts << {
                :type => mo.binread(4, 8 + 20*i).unpack('H8').first,
                :subtype => mo.binread(4, 12 + 20*i).unpack('H8').first
              }
            end # do each |i|
            native_parts = []
            foreign_parts = []
            parts.each do |part|
              if arch = cpu_valid(part[:type], part[:subtype])
                native_parts << Term_seq.in_br_cyan(arch)
              else
                ct = (CPU_TYPES[part[:type]] or part[:type])
                foreign_parts << {
                  [ct, part[:subtype]] =>
                    "[foreign CPU type #{Term_seq.in_cyan(ct)} with subtype #{Term_seq.in_cyan(part[:subtype])}.]"
                }
              end # arch?
            end # do each |part|
        # Second, sort the list:
            native_parts.sort! do |a, b|
              # the ꜱɢʀ sequences at beginning and end are 5 characters each
              if (a[5..7] == 'ppc' and b[5..7] == 'ppc')
                # sort ppc64 after all other ppc types
                if a[8..-6] == '64'
                  1
                elsif b[8..-6] == '64'
                  -1
                else 
                  a <=> b
                end
              else
                a <=> b
              end # ppc_x_?
            end # sort! native parts
            foreign_parts.sort! do |a, b|
              if a.keys.first[0] < b.keys.first[0]
                -1
              elsif a.keys.first[0] > b.keys.first[0]
                1
              else
                a.keys.first[1] <=> b.keys.first[1]
              end # compare CPUtype or else compare subtype
            end # sort! foreign parts
            parts = native_parts + foreign_parts.map { |h| Term_seq.in_cyan("#{h.keys.first[0]}:#{h.keys.first[1]}") }
        # Third, use the sorted list as a search key:
            key = parts
            alien_reports << "File #{Term_seq.in_white(mo)}:\n  #{foreign_parts.map { |fp| fp.values.first }.join("\n  ")}\n" if foreign_parts != []
          end # (1 <= arch_count <= 7)?
        elsif sig # :MH_MAGIC, :MH_MAGIC_64
        # Generate a key from a one‐architecture file:
          cpu = {
            :type => mo.binread(4, 4).unpack('H8').first,
            :subtype => mo.binread(4, 8).unpack('H8').first
          }
          if arch = cpu_valid(cpu[:type], cpu[:subtype])
            key = [Term_seq.in_br_cyan(arch)]
          else # alien arch
            ct = (CPU_TYPES[cpu[:type]] or cpu[:type])
            key = [Term_seq.in_cyan("#{ct}:#{cpu[:subtype]}")]
            alien_reports << "File #{Term_seq.in_white(mo)}:\n  [foreign CPU type #{Term_seq.in_cyan(ct)} with subtype #{Term_seq.in_cyan(cpu[:subtype])}.\n"
          end # native arch?
        end # Fat / Mach-O sig?
        if arch_reports[key]
          arch_reports[key] += 1
        else
          arch_reports[key] = 1
        end
      end # do each |mo|

      if arch_reports == {}
        oho "#{Term_seq.in_white(keg.name)} appears to contain #{Term_seq.in_yellow('no valid Mach-O files')}."
        no_archs_msg = true
      else
        ohey("#{Term_seq.in_white(keg.name)} appears to contain some foreign code:", alien_reports.join('')) if alien_reports != []
        mode = arch_reports.key(arch_reports.values.max).length
        reps = arch_reports.select { |k, v| v == arch_reports.values.max }.keys
        if thorough_flag
          oho "#{Term_seq.in_white("#{keg.name} #{keg.root.basename}")} is built for ",
            (reps.length > 1 ?
              "#{Term_seq.in_br_white(reps.length)} combinations of architecture" :
              "#{Term_seq.in_br_white(mode)} architecture#{plural(mode)}"),
            ":  #{reps.map { |r| r.join(Term_seq.in_white('/')) + " (#{'×' + arch_reports[r].to_s})" }.join(', ')}."
        else
          reps = reps.reject { |r| r.any? { |rr| rr =~ /ppc‐\*/ } } if reps.length > 1
          oho "#{Term_seq.in_white(keg.name)} is built for ",
            "#{Term_seq.in_br_white(mode)} architecture#{plural(mode)}",
            ":  #{reps.map { |r| r.join(Term_seq.in_white('/')) }.join(' | ')}."
        end # thorough?
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
