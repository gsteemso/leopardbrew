#:List what hardware architectures each given /installed formula/ was brewed for.
#:The data supplied by the brewing system is uneven, so code made for PowerPCs is
#:labelled with more specificity than code built for Intel-compatible CPUs.
#:
#:  Usage:  brew list-archs /installed formula/ [...]
#:
#:The results are shown after a short delay.  (Certain formulae do weird things
#:which require every last file within each keg to be examined.)
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
  '00000000' => 'ppc-all',
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

def cpu_valid(type, subtype)
  case CPU_TYPES[type]
  when 'i386', 'x86-64'
    CPU_TYPES[type]
  when 'PPC'
    PPC_SUBTYPES[subtype]
  when 'PPC64'
    'ppc64'
  else
    nil
  end
end # cpu_valid

module Term_seq # standard terminal display-control sequences (yes, can be a wrong assumption)
  module_function
  # - In the 7-bit environment UTF-8 imposes, the Control Sequence Introducer (CSI) is "ESC `[`".
  def csi ; "\033[" ; end
  # - Control sequences containing multiple parameters separate them by `;`.
  # - The Select Graphic Rendition (SGR) sequence is "CSI <Ps> ... `m`".
  def sgr(*list) ; "#{csi}#{list.join(';')}m" ; end
  # - The SGR parameters are:
  def rst    ;   '0' ; end # cancels everything.
  def boldr  ;   '1' ; end # } in theory, these two stack and unstack with each other, but most
  def fntr   ;   '2' ; end # } terminal emulators don't support 2.
             #    3 was for Italic face, and cancelled 20.
  def undr   ;   '4' ; end # cancels 21.
             #    5-6 were for slow vs. fast blink; don't care whether they work, flashing is vile.
  def rvs    ;   '7' ; end # inverse video; cancels 27.
  def hidn   ;   '8' ; end # no display; cancels 28.
  def strk   ;   '9' ; end # strikethrough ("shown as deleted").
             #   10-19 selected the default font 0, or alternate fonts 1-9.
             #   20 was for Gothic face, and cancelled 3.
  def d_undr ;  '21' ; end # cancels 4; probably unsupported by Terminal.app on Tiger or Leopard.
  def reg_wt ;  '22' ; end # cancels 1-2; probably unsupported by Terminal.app on Tiger or Leopard.
             #   23 was for returning to Roman face (cancelled 3 & 20).
  def noundr ;  '24' ; end # cancels 4 & 21.
             #   25 cancelled blinking (5-6).
             #   26 was reserved for proportional-width characters.
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
             #   38 is for extensions to higher-bit-depth foreground colours; Terminal.app doesn't
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
             #   48 is for extensions to higher-bit-depth background colours; Terminal.app doesn't
             #      support any of them under Tiger or Leopard.
  def ondflt ;  '49' ; end # default background colour.
             #   50 was reserved to cancel 26.
             #   51-53 were "framed", "circled", & "overlined".
             #   54 cancelled 51-52 and 55 cancelled 53.
             #   56-59 were unused.
             #   60-64 were for ideographs (underline/right-line; double of; overline/left-line;
             #         double of; stress mark); 65 cancelled them.
  # - The following are extensions -- Tiger's Terminal.app treats them the same as their non-bright
  #   counterparts, but Leopard's does present them as brighter.
  def br_blk ;  '90' ; end # }
  def br_red ;  '91' ; end # }
  def br_grn ;  '92' ; end # }
  def br_ylw ;  '93' ; end # } "display" (foreground) colours.
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

  # - SGR is affected by the Graphic Rendition Combination Mode (GRCM).  The default (off) GRCM
  #   state, REPLACING, causes any SGR sequence to reset all parameters it doesn't explicitly
  #   mention; enabling the CUMULATIVE state allows effects to persist until cancelled.  Luckily,
  #   OS X's Terminal app seems to ignore the standard and default this to the more sensible
  #   CUMULATIVE state, at least under Leopard.
  # - If GRCM is in the REPLACING state and needs to be set CUMULATIVE, the Set Mode (SM) sequence
  #   is "CSI <Ps> ... `h`" and the parameter value for GRCM is 21.  Should it for some reason need
  #   to be changed back to REPLACING, the Reset Mode (RM) sequence is "CSI <Ps> ... `l`".
  def self.set_gcrm_cumulative ; "#{csi}21h" ; end
  def self.set_gcrm_replacing  ; "#{csi}21l" ; end

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
    self.size >= 28 and
    SIGNATURES[self.binread(4).unpack('H8').first]
  end
end # Pathname

module Homebrew
  Term_seq.set_gcrm_cumulative

  def list_archs
    def oho(msg)
      puts "#{Term_seq.bolder_on_black}#{Term_seq.in_br_blue '==>'} #{msg}#{Term_seq.reset_gr}"
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

    requested = ARGV.kegs
    raise KegUnspecifiedError if requested.empty?
    no_archs_msg = false
    requested.each do |keg|
      max_arch_count = 0
      # file count and list of native architectures, for each of 1- through 6-architecture Mach-O
      # and fat-binary files (element 0 is unused)
      arch_reports = [
        {:file_count => 0, :native_parts => []},
        {:file_count => 0, :native_parts => []},
        {:file_count => 0, :native_parts => []},
        {:file_count => 0, :native_parts => []},
        {:file_count => 0, :native_parts => []},
        {:file_count => 0, :native_parts => []},
        {:file_count => 0, :native_parts => []}
      ]
      alien_reports = []
      scour(keg.to_s).each do |mo|
        sig = mo.mach_o_signature?
        if sig == :FAT_MAGIC
          arch_count = mo.binread(4,4).unpack('N').first
          # False positives happen, especially with Java files; if the no. of architectures is
          #   negative, zero, one, or implausibly large, it probably isn't actually a fat binary.
          # Pick an upper limit of 6 in case we ever have to handle ARM/ARM64 builds or whatever.
          if (arch_count > 1 and arch_count <= 6)
            arch_reports[arch_count][:file_count] += 1
            max_arch_count = arch_count if arch_count > max_arch_count
            # generate a report for file found containing this number of architectures
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
                foreign_parts << "[foreign CPU type #{Term_seq.in_cyan(ct)} with subtype #{Term_seq.in_cyan(part[:subtype])}."
              end # arch?
            end # do each |part|
            # sort ppc64 after all other ppc types
            native_parts.sort! do |a, b|
              # the SGR sequences at beginning and end are 5 characters each
              if (a[5..7] == 'ppc' and b[5..7] == 'ppc')
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
            end # sort!
            if arch_reports[arch_count][:native_parts] = []
              arch_reports[arch_count][:native_parts] << {:archlist_count => 1, :archlist => native_parts}
            else
              arch_reports[arch_count][:native_parts].each do |np|
                if np[:archlist] == native_parts
                  np[:archlist_count] += 1
                else
                  np << {:archlist_count => 1, :archlist => native_parts}
                end # is archlist already seen?
              end # do each |np|
            end # already got any :native_parts?
            alien_reports << "File #{Term_seq.in_white(mo)}:\n  #{foreign_parts.join("\n  ")}\n" if foreign_parts != []
          end # 1 < arch_count <= 6 ?
        elsif sig # :MH_MAGIC, :MH_MAGIC_64
          arch_reports[1][:file_count] += 1
          max_arch_count = 1 if max_arch_count == 0
          # generate a report for file found containing one architecture
          cpu = {
            :type => mo.binread(4, 4).unpack('H8').first,
            :subtype => mo.binread(4, 8).unpack('H8').first
          }
          if arch = cpu_valid(cpu[:type], cpu[:subtype])
            native_part = [Term_seq.in_br_cyan(arch)]
            if arch_reports[1][:native_parts] = []
              arch_reports[1][:native_parts] << {:archlist_count => 1, :archlist => native_part}
            else
              arch_reports[1][:native_parts].each do |np|
                if np[:archlist] == native_part
                  np[:archlist_count] += 1
                else
                  np << {:archlist_count => 1, :archlist => native_part}
                end # is archlist already seen?
              end # do each |np|
            end # already got any :native_parts?
          else # alien arch
            ct = (CPU_TYPES[cpu[:type]] or cpu[:type])
            alien_reports << "File #{Term_seq.in_white(mo)}:\n  [foreign CPU type #{Term_seq.in_cyan(ct)} with subtype #{Term_seq.in_cyan(cpu[:subtype])}.\n"
          end # native arch?
        end # Mach-O sig?
      end # do each |mo|
      if max_arch_count == 0
        oho "#{Term_seq.in_white(keg.name)} appears to contain #{Term_seq.in_yellow('no valid Mach-O files')}."
        no_archs_msg = true
      else
        ohey("#{Term_seq.in_white(keg.name)} appears to contain some foreign code:", alien_reports.join('')) if alien_reports != []
        modal_average = 0
        arch_index = 0
        arch_reports.each_index do |i|
          if arch_reports[i][:file_count] >= modal_average
            modal_average = arch_reports[i][:file_count]
            arch_index = i
          end # did more files have _this_ many architectures?
        end # do each |i|
        modal_average = 0
        archlist_index = 0
        arch_reports[arch_index][:native_parts].each_index do |i|
          if arch_reports[arch_index][:native_parts][i][:archlist_count] > modal_average
            modal_average = arch_reports[arch_index][:native_parts][i][:archlist_count]
            archlist_index = i
          end # did more files have _this_ specific list of architectures?
        end # do each |i|
        architectures = 'architecture' + plural(arch_index)
        oho "#{Term_seq.in_white(keg.name)} is built for #{Term_seq.in_br_white(arch_index)} #{architectures}:  #{arch_reports[arch_index][:native_parts][archlist_index][:archlist].join(', ')}."
      end # any archs found?
    end # do each |keg|
    if no_archs_msg
      puts <<-_.undent
        Sometimes a successful brew produces no Mach-O files.  This can happen if, for
        example, the formula responsible installs only header or documentation files.
      _
    end # no_archs_msg?
  end # list_archs
end # Homebrew
